package com.cognizant.vibecoding.stocktrading.service;

import com.cognizant.vibecoding.stocktrading.dto.StockPriceDto;
import com.cognizant.vibecoding.stocktrading.model.Stock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

@Service
@RequiredArgsConstructor
@Slf4j
public class StockPriceSimulationService {

    private final StockService stockService;
    private final SimpMessagingTemplate messagingTemplate;
    private final Random random = new Random();

    // Sample stocks to create if they don't exist
    private final List<String[]> sampleStocks = Arrays.asList(
            new String[]{"AAPL", "Apple Inc.", "150.00"},
            new String[]{"GOOGL", "Alphabet Inc.", "2800.00"},
            new String[]{"MSFT", "Microsoft Corporation", "330.00"},
            new String[]{"AMZN", "Amazon.com Inc.", "3200.00"},
            new String[]{"TSLA", "Tesla Inc.", "800.00"},
            new String[]{"META", "Meta Platforms Inc.", "320.00"},
            new String[]{"NVDA", "NVIDIA Corporation", "450.00"},
            new String[]{"NFLX", "Netflix Inc.", "400.00"},
            new String[]{"AMD", "Advanced Micro Devices", "110.00"},
            new String[]{"ORCL", "Oracle Corporation", "85.00"}
    );

    @Scheduled(fixedRate = 3000) // Update every 3 seconds
    public void simulateStockPriceUpdates() {
        try {
            // Initialize sample stocks if needed
            initializeSampleStocks();
            
            // Get all stocks and update some randomly
            List<StockPriceDto> allStocks = stockService.getAllStocks();
            
            if (!allStocks.isEmpty()) {
                // Update 30-50% of stocks randomly
                int stocksToUpdate = Math.max(1, random.nextInt(allStocks.size() / 2) + 1);
                
                for (int i = 0; i < stocksToUpdate; i++) {
                    StockPriceDto randomStock = allStocks.get(random.nextInt(allStocks.size()));
                    updateStockPrice(randomStock);
                }
            }
        } catch (Exception e) {
            log.error("Error during stock price simulation: {}", e.getMessage());
        }
    }

    private void initializeSampleStocks() {
        for (String[] stockData : sampleStocks) {
            String symbol = stockData[0];
            if (stockService.getStockBySymbol(symbol).isEmpty()) {
                stockService.createStock(symbol, stockData[1], new BigDecimal(stockData[2]));
                log.info("Created sample stock: {} - {}", symbol, stockData[1]);
            }
        }
    }

    private void updateStockPrice(StockPriceDto stock) {
        // Generate random price change between -5% and +5%
        double changePercent = (random.nextDouble() - 0.5) * 0.1; // -5% to +5%
        BigDecimal currentPrice = stock.getCurrentPrice();
        BigDecimal change = currentPrice.multiply(BigDecimal.valueOf(changePercent));
        BigDecimal newPrice = currentPrice.add(change).setScale(2, RoundingMode.HALF_UP);
        
        // Ensure price doesn't go below $1
        if (newPrice.compareTo(BigDecimal.ONE) < 0) {
            newPrice = BigDecimal.ONE;
        }

        try {
            StockPriceDto updatedStock = stockService.updateStockPrice(stock.getSymbol(), newPrice);
            
            // Send real-time update via WebSocket
            messagingTemplate.convertAndSend("/topic/stock-updates", updatedStock);
            log.debug("Updated and broadcasted price for {}: ${}", 
                     updatedStock.getSymbol(), updatedStock.getCurrentPrice());
        } catch (Exception e) {
            log.error("Error updating stock price for {}: {}", stock.getSymbol(), e.getMessage());
        }
    }
} 