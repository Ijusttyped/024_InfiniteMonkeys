#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

library(shiny)
library(dplyr)
library(ggplot2)
library(DBI)
library(openssl)
library(RSQLite)

# Database ----------------------------------------------------------------

DB_NAME <- "data.sqlite"
TBL_USER_DATA <- "users"
DB_test_connect <- function(){
  db <- dbConnect(SQLite(), DB_NAME)
  print("#######################")
  print("- Connected to Database")
  # If a user data table doesn't already exist, create one
  if(!(TBL_USER_DATA %in% dbListTables(db))){
    print("- Warning: No 'users' table found. Creating table...")
    df <- data.frame(ID = as.numeric(character()),
                     USER = character(),
                     HASH = character(),
                     stringsAsFactors = FALSE)
    dbWriteTable(db, TBL_USER_DATA, df)
  } 
  print("- Table exists.")
  print("#######################")
  dbDisconnect(db)
}

DB_upload_csv <- function(filename, tblname){
  db <- dbConnect(SQLite(), DB_NAME)
  df <- read.csv(file = filename, header = T, row.names = F, stringsAsFactors = F)
  dbWriteTable(db, tblname, df)
  dbDisconnect(db)
}

DB_get_user <- function(user){
  db <- dbConnect(SQLite(), DB_NAME)
  users_data <- dbReadTable(db, TBL_USER_DATA)
  hashusers_data <- filter(users_data, USER == user)
  dbDisconnect(db)
  return(users_data)
}

DB_get_single_user <- function(user){
  db <- dbConnect(SQLite(), DB_NAME)
  users_data <- dbReadTable(db, TBL_USER_DATA)
  hashusers_data <- filter(users_data, USER == user)
  dbDisconnect(db)
  return(hashusers_data)
}

DB_add_user <- function(usr, hsh){
  db <- dbConnect(SQLite(), DB_NAME)
  df <- dbReadTable(db, TBL_USER_DATA)
  q <- paste("INSERT INTO", TBL_USER_DATA, "(ID, USER, HASH) VALUEs (", paste("", nrow(df), ",", usr, ",", hsh, "", sep="'"), ")")
  #print(q)
  dbSendQuery(db, q)
  suppressWarnings({dbDisconnect(db)})
}

# Init Database -----------------------------------------------------------
DB_test_connect()

# Define server logic required to draw a histogram
shinyServer(function(input, output, session) {
  ###################################################
  ### this is the login part
  ###################################################
  loggedIn <- reactiveVal(value = FALSE)
  user <- reactiveVal(value = NULL)
  login <- eventReactive(input$login, {
    user_data <- DB_get_user(input$username)
    get_user <- DB_get_single_user(input$username)
    print("user data")
    print(get_user)
    print(user_data)
    if(nrow(user_data) > 0){ # If the active user is in the DB then logged in
      if(sha256(input$password) == get_user[1, "HASH"]){
        print("inside IF2")
        user(input$username)
        loggedIn(TRUE)
        print(paste("- User:", user(), "logged in"))
        return(TRUE)
      }
    }
    return(FALSE)
  })
  register_user <- eventReactive(input$register_user, {
    users_data <- DB_get_user(input$new_user)
    get_user <- DB_get_single_user(input$new_user)
    if(nrow(get_user) > 0){
      return(span("User already exists", style = "color:red"))
    }
    new_hash <- sha256(input$new_pw)
    new_user <- input$new_user
    DB_add_user(new_user, new_hash)
    print("- New user added to database")
    return(span("New user registered", style = "color:green"))
  })
  
  output$register_status <- renderUI({
    if(input$register_user == 0){
      return(NULL)
    } else {
      register_user()
    }
  })
  output$login_status <- renderUI({
    if(input$login == 0){
      return(NULL)
    } else {
      if(!login()){
        print("inside incorrect details")
        return(span("The Username or Password is Incorrect", style = "color:red"))
      }
    }
  })
  
  observeEvent(input$create_login, {
    showModal(
      modalDialog(title = "Create Login", size = "m", 
                  textInput(inputId = "new_user", label = "Username"),
                  passwordInput(inputId = "new_pw", label = "Password"),
                  actionButton(inputId = "register_user", label = "Submit"),
                  p(input$register_user),
                  uiOutput("register_status")
      )
    )
    register_user()
  })
  
  observeEvent(input$logout, {
    user(NULL)
    loggedIn(FALSE)
    print("- User: logged out")
  })
  
  observe({
    if(loggedIn()){
      output$App_Panel <- renderUI({
        fluidPage(
          fluidRow(
            strong(paste("logged in as", user(), "|")), actionLink(inputId = "logout", "Logout"), align = "right",
            hr()
          ),
          fluidRow(
            titlePanel("Hospital Capacity Map"),
            # Sidebar with a slider input for number of bins 
            sidebarLayout(
              mainPanel(
                leafletOutput("map")
              ),
              sidebarPanel(
                tabsetPanel(type = "tabs",
                            tabPanel("Kapzitaeten suchen",
                                     radioButtons("marker",
                                                  h5("Bitte die Kategorie auswaehlen"),
                                                  c("icuLowCare" = "icuLowCare",
                                                    "icuHighCare" = "icuHighCare",
                                                    "ecmo" = "ecmo")),
                                     numericInput("bed", 
                                                  "Wie viele Betten werden gefragt?", 
                                                  3, min=1),
                                     numericInput("pat", 
                                                  "Wie viele Patiente sollen behandelt werden?", 
                                                  3, min=1),
                                     numericInput("device", 
                                                  "Wie viele Geraete werden gefragt?", 
                                                  10, min=1),
                                     numericInput("mask", 
                                                  "Wie viele Mundschutzmaske werden gefragt?", 
                                                  100, min=1),
                                     sliderInput("range", 
                                                 "Wie weit (km) sollen die Krankenhaeuser liegen?", 
                                                 min = 1, 
                                                 max = 500, 
                                                 value = 30),
                                     actionButton("button", 
                                                  "Submit", 
                                                  style="color: #fff; background-color: #037367")
                                     ),
                            tabPanel("Meine Daten aktualisieren",
                                     textInput("bedused", "Wie viele Betten werden momentan besetzt?", 30),
                                     textInput("patused", "Wie viele Patiente werden momentan behandelt?", 30),
                                     textInput("deviceused", "Wie viele Geraete werden gefragt?", 100),
                                     actionButton("buttonused",
                                                  "Save",
                                                  style="color: #fff; background-color: #60412b")
                            ))
              )
            )
          )
        )
      })
      
    } else {
      output$App_Panel <- renderUI({
        fluidPage(
          fluidRow(
            hr(),
            titlePanel(title = "Willkommen zum Deutschland Klinken Plattform"), align = "center"
          ),
          fluidRow(
            column(4, offset = 4,
                   wellPanel(
                     h2("Login", align = "center"),
                     textInput(inputId = "username", label = "Username"),
                     passwordInput(inputId = "password", label = "Password"),
                     fluidRow(
                       column(4, offset = 4, actionButton(inputId = "login", label = "Login")),
                       column(4, offset = 4, actionLink(inputId = "create_login", label = "Create login")),
                       column(6, offset = 3, uiOutput(outputId = "login_status")
                       )
                     )
                   )
            )
          )
        )
      })
    }
  })
  ###############################################
  ### This is the processing part
  ###############################################
  df_raw <- read.csv("divi_data.csv",header=TRUE,sep=",")
 # df_raw$icuHighCare<-sapply(df_raw$icuHighCare,
  #                              function(col_df){
  #                                if(col_df=="RED"){"darkred"}
  #                                else if(col_df=="darkred"){"darkred"}
  #                                else if(col_df=="YELLOW"){"orange"}
  #                                else if{"green"}
  #                                })
  df_raw$icuLowCare<-sapply(df_raw$icuLowCare,
                                function(col_df){
                                  if(col_df=="RED"){"darkred"}
                                  else if(col_df=="YELLOW"){"orange"}
                                  else {"green"}
                                })   
  df_raw$ecmo<-sapply(df_raw$ecmo,
                         function(col_df){
                           if(col_df=="RED"){"darkred"}
                           else if(col_df=="YELLOW"){"orange"}
                           else {"green"}
                          }) 
  df_raw <- df_raw %>% 
    mutate(available_bed=Intensive_Care-Critical_Patients) %>%
    mutate(transfer_pat=Normal_Patients-Normal_Care)
  df_result <- reactive({
    df_raw %>% 
      filter(available_bed>=input$bed) %>%
      filter(transfer_pat>=input$pat) %>%
      filter(device>=input$device) %>%
      filter(mask>=input$mask) %>%
      select(name,input$marker,latitude,longitude)
  })
#  marker_color <- reactive({input$marker})
  output$map <- renderLeaflet({
    leaflet() %>%
      setView(lat=50.935173, lng=6.953101, zoom=8.5) %>%
      addTiles() %>%
      addAwesomeMarkers(lat=df_result()$latitude,
                        lng=df_result()$longitude,
                        icon=awesomeIcons(
                          library = 'ion',
                          markerColor = df_result()[,2]
                        ),
                        label=df_result()$name)
  })
})
