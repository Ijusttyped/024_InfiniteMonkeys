/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package de.jbader.divi.crawler;

import java.net.URL;
import java.util.Date;

/**
 *
 * @author jbader
 */
public class ClinicStatusData {
    public enum Status {
        GREEN,
        YELLOW,
        RED
    }
    
    private String name;
    private String contact;
    private URL url;
    
    private String state;
    
    private Status icuLowCare;
    private Status icuHighCare;
    private Status ecmo;
    
    private Date timestamp;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getContact() {
        return contact;
    }

    public void setContact(String contact) {
        this.contact = contact;
    }

    public URL getUrl() {
        return url;
    }

    public void setUrl(URL url) {
        this.url = url;
    }

    public String getState() {
        return state;
    }

    public void setState(String state) {
        this.state = state;
    }

    public Status getIcuLowCare() {
        return icuLowCare;
    }

    public void setIcuLowCare(Status icuLowCare) {
        this.icuLowCare = icuLowCare;
    }

    public Status getIcuHighCare() {
        return icuHighCare;
    }

    public void setIcuHighCare(Status icuHighCare) {
        this.icuHighCare = icuHighCare;
    }

    public Status getEcmo() {
        return ecmo;
    }

    public void setEcmo(Status ecmo) {
        this.ecmo = ecmo;
    }

    public Date getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(Date timestamp) {
        this.timestamp = timestamp;
    }
    
    
    
}
