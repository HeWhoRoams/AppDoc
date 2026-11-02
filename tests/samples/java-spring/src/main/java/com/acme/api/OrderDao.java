package com.acme.api;

import java.io.File;
import java.nio.file.Files;
import javax.sql.DataSource;
import org.springframework.context.annotation.Bean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.web.reactive.function.client.WebClient;

public class OrderDao {
    private static final String DB_PASSWORD = "Sup3rS3cretPw!";
    private JdbcTemplate jdbcTemplate;
    private JavaMailSender mailSender;

    public void load() {
        jdbcTemplate.update("INSERT INTO order_log (id, msg) VALUES (?, ?)", 1, "x");
        jdbcTemplate.query("select * from customers c where c.id = ?", (rs, i) -> rs.getString(1), 1);
        new SimpleJdbcCall(jdbcTemplate).withProcedureName("sp_close_order");
        // jdbcTemplate.update("delete from ghost_table where 1=1");
    }

    public void io() throws Exception {
        File f = new File("/var/spool/orders.csv");
        Files.readAllBytes(f.toPath());
        mailSender.send(null);
        WebClient.create("https://pricing.acme.internal/v1").get();
        new ProcessBuilder("/usr/bin/convert", "--token=abc123XYZ").start();
        Object o = ctx.lookup("java:comp/env/jdbc/OrdersDS");
    }

    @Bean
    public DataSource ordersDataSource() {
        return DataSourceBuilder.create().username("orders").password("BeanP@ss777").build();
    }
}
