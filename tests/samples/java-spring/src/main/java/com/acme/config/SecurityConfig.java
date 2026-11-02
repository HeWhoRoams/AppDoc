package com.acme.config;

import org.springframework.security.config.annotation.web.builders.HttpSecurity;

public class SecurityConfig {
    protected void configure(HttpSecurity http) throws Exception {
        http.authorizeRequests()
            .antMatchers("/admin/**", "/ops/*").hasRole("ADMIN")
            .antMatchers("/public/**").permitAll()
            .anyRequest().authenticated()
            .and().formLogin();
    }
}
