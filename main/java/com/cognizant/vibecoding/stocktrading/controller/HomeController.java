package com.cognizant.vibecoding.stocktrading.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.util.HashMap;
import java.util.Map;

@Controller
public class HomeController {

    @GetMapping("/")
    public String index() {
        return "index.html";
    }

    @GetMapping("/api/info")
    @ResponseBody
    public Map<String, Object> getApiInfo() {
        Map<String, Object> info = new HashMap<>();
        info.put("application", "Stock Trading App");
        info.put("version", "1.0.0");
        info.put("description", "Real-time stock price tracking application");
        info.put("endpoints", Map.of(
            "getAllStocks", "/api/stocks",
            "getStockBySymbol", "/api/stocks/{symbol}",
            "getTopGainers", "/api/stocks/gainers",
            "getTopLosers", "/api/stocks/losers",
            "webSocketEndpoint", "/ws"
        ));
        return info;
    }
} 