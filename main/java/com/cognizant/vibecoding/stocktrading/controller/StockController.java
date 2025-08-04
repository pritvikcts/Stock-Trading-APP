package com.cognizant.vibecoding.stocktrading.controller;

import com.cognizant.vibecoding.stocktrading.dto.StockPriceDto;
import com.cognizant.vibecoding.stocktrading.service.StockService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/stocks")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class StockController {

    private final StockService stockService;

    @GetMapping
    public ResponseEntity<List<StockPriceDto>> getAllStocks() {
        List<StockPriceDto> stocks = stockService.getAllStocks();
        return ResponseEntity.ok(stocks);
    }

    @GetMapping("/{symbol}")
    public ResponseEntity<StockPriceDto> getStockBySymbol(@PathVariable String symbol) {
        return stockService.getStockBySymbol(symbol)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/gainers")
    public ResponseEntity<List<StockPriceDto>> getTopGainers() {
        List<StockPriceDto> gainers = stockService.getTopGainers();
        return ResponseEntity.ok(gainers);
    }

    @GetMapping("/losers")
    public ResponseEntity<List<StockPriceDto>> getTopLosers() {
        List<StockPriceDto> losers = stockService.getTopLosers();
        return ResponseEntity.ok(losers);
    }
} 