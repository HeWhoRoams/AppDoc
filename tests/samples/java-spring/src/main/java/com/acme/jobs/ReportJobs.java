package com.acme.jobs;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.env.Environment;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class ReportJobs {

    private final Environment env;

    @Value("${reports.output-dir:/tmp/reports}")
    private String outputDir;

    public ReportJobs(Environment env) {
        this.env = env;
    }

    @Scheduled(fixedRate = 60000)
    public void refreshCache() {
    }

    @Scheduled(cron = "0 30 2 * * *")
    @ConditionalOnProperty("reports.enabled")
    public void nightlyReport() {
        String sink = env.getProperty("reports.sink.url");
        String token = System.getenv("REPORT_API_TOKEN");
    }

    @Scheduled(cron = "-")
    public void disabledJob() {
    }
}
