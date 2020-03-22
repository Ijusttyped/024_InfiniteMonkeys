/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package de.jbader.divi.crawler;

import com.google.gson.stream.JsonWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.net.MalformedURLException;
import java.net.URL;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import org.apache.http.client.fluent.Form;
import org.apache.http.client.fluent.Request;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;

/**
 *
 * @author jbader
 */
public class Main {

    public static void main(String[] args) throws Exception {
        Form form = Form.form()
                .add("filter[search]", "")
                .add("list[fullordering]", "a.title ASC")
                .add("list[limit]", "0")
                .add("filter[federalstate]", "0")
                .add("filter[chronosort]", "0")
                .add("filter[icu_highcare_state]", "")
                .add("filter[ards_network]", "")
                .add("flimitstart", "0")
                .add("task", "")
                .add("boxchecked", "0");

        String result = Request.Post("https://divi.de/register/intensivregister?view=items")
                .bodyForm(form.build())
                .execute().returnContent().asString();

        Document doc = Jsoup.parse(result);
        Elements table = doc.select("#dataList");
        Elements body = table.select("tbody");
        Elements entries = body.select("tr");

        final JsonWriter jsonWriter = beginJSONOutput();

        entries.forEach((entry) -> {
            ClinicStatusData statusData = parse(entry);

            try
            {
                jsonOutput(jsonWriter, statusData);
            }
            catch(IOException ex)
            {
                ex.printStackTrace();
            }
            
            persistInDatabase(statusData);
        });

        endJSONOutput(jsonWriter);
    }

    private static ClinicStatusData parse(Element entry) {
        ClinicStatusData statusData = new ClinicStatusData();

        statusData.setName(entry.child(0).text());
        statusData.setContact(entry.child(1).text().replace("Website", "").trim());

        String urlStr = entry.child(1).select("a").attr("href");
        try {
            if (urlStr.contains("@")) {
                urlStr = "mailto:" + urlStr;
            }

            if (urlStr.startsWith("/")) {
                urlStr = "https:/" + urlStr;
            }

            if (!urlStr.isEmpty()) {
                statusData.setUrl(new URL(urlStr));
            }
        } catch (MalformedURLException ex) {
            ex.printStackTrace();
        }

        statusData.setState(entry.child(2).text());
        statusData.setIcuLowCare(parseStatus(entry.child(3).select("span").attr("class")));
        statusData.setIcuHighCare(parseStatus(entry.child(4).select("span").attr("class")));
        statusData.setEcmo(parseStatus(entry.child(5).select("span").attr("class")));

        String statusTimestamp = entry.child(6).text();

        SimpleDateFormat formatter = new SimpleDateFormat("dd.MM.yyyy hh:mm");

        try {
            statusData.setTimestamp(formatter.parse(statusTimestamp));
        } catch (ParseException ex) {
            ex.printStackTrace();
        }

        return statusData;
    }

    private static ClinicStatusData.Status parseStatus(final String statusStr) {
        switch (statusStr) {
            case "hr-icon-green":
                return ClinicStatusData.Status.GREEN;
            case "hr-icon-yellow":
                return ClinicStatusData.Status.YELLOW;
            case "hr-icon-red":
                return ClinicStatusData.Status.RED;
            default:
                return null;
        }
    }

    private static void persistInDatabase(ClinicStatusData statusData) {
        // todo
    }

    private static JsonWriter beginJSONOutput() throws IOException {
        JsonWriter writer = new JsonWriter(new OutputStreamWriter(System.out));

        writer.beginObject();
        writer.name("clinicStatus");
        writer.beginArray();

        return writer;
    }

    private static void endJSONOutput(JsonWriter writer) throws IOException {
        writer.endArray();

        writer.endObject();
        writer.close();
    }

    private static void jsonOutput(JsonWriter writer, ClinicStatusData statusData) throws IOException {
        writer.beginObject();
        
        writer.name("name").value(statusData.getName());
        writer.name("contact").value(statusData.getContact());
        
        URL url = statusData.getUrl();
        if(url!=null) {
            writer.name("url").value(url.toString());
        }
        
        writer.name("state").value(statusData.getState());     
        
        jsonWriteStatus(writer, "icuLowCare", statusData.getIcuLowCare());
        jsonWriteStatus(writer, "icuHighCare", statusData.getIcuHighCare());
        jsonWriteStatus(writer, "ecmo", statusData.getEcmo());
        
        writer.name("timestamp").value(statusData.getTimestamp().toString());
                
        writer.endObject();
    }
    
    private static void jsonWriteStatus(JsonWriter writer, String statusName, ClinicStatusData.Status status) throws IOException {
        if(status!=null) {
            writer.name(statusName).value(status.toString());
        }
    }
}
