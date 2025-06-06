package com.example.logbackend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.boot.WebApplicationType;

@SpringBootApplication
@ComponentScan(basePackages = "com.example.logbackend") 
public class LogbackendApplication {

    public static void main(String[] args) {
        SpringApplication app = new SpringApplication(LogbackendApplication.class);
        app.setWebApplicationType(WebApplicationType.SERVLET);
        app.run(args);
    }
}
