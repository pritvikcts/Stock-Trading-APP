package com.cognizant.vibecoding.stocktrading.service;

import com.cognizant.vibecoding.stocktrading.dto.StockPriceDto;
import com.cognizant.vibecoding.stocktrading.model.Stock;
import com.cognizant.vibecoding.stocktrading.repository.StockRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class StockService {

    private final StockRepository stockRepository;

    public List<StockPriceDto> getAllStocks() {
        return stockRepository.findAllOrderByLastUpdatedDesc()
                .stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    public Optional<StockPriceDto> getStockBySymbol(String symbol) {
        return stockRepository.findBySymbol(symbol.toUpperCase())
                .map(this::convertToDto);
    }

    public StockPriceDto updateStockPrice(String symbol, BigDecimal newPrice) {
        Stock stock = stockRepository.findBySymbol(symbol.toUpperCase())
                .orElseThrow(() -> new RuntimeException("Stock not found: " + symbol));

        BigDecimal previousClose = stock.getPreviousClose() != null ? 
                                 stock.getPreviousClose() : stock.getCurrentPrice();
        
        BigDecimal changeAmount = newPrice.subtract(previousClose);
        BigDecimal changePercentage = previousClose.compareTo(BigDecimal.ZERO) != 0 ?
                changeAmount.divide(previousClose, 4, RoundingMode.HALF_UP)
                          .multiply(BigDecimal.valueOf(100)) : BigDecimal.ZERO;

        stock.setCurrentPrice(newPrice);
        stock.setChangeAmount(changeAmount);
        stock.setChangePercentage(changePercentage);
        stock.setLastUpdated(LocalDateTime.now());

        // Update day high/low
        if (stock.getDayHigh() == null || newPrice.compareTo(stock.getDayHigh()) > 0) {
            stock.setDayHigh(newPrice);
        }
        if (stock.getDayLow() == null || newPrice.compareTo(stock.getDayLow()) < 0) {
            stock.setDayLow(newPrice);
        }

        Stock savedStock = stockRepository.save(stock);
        log.info("Updated stock price for {}: ${}", symbol, newPrice);
        
        return convertToDto(savedStock);
    }

    public Stock createStock(String symbol, String companyName, BigDecimal initialPrice) {
        Stock stock = new Stock(symbol.toUpperCase(), companyName, initialPrice);
        stock.setPreviousClose(initialPrice);
        stock.setChangeAmount(BigDecimal.ZERO);
        stock.setChangePercentage(BigDecimal.ZERO);
        stock.setDayHigh(initialPrice);
        stock.setDayLow(initialPrice);
        stock.setVolume(0L);
        
        return stockRepository.save(stock);
    }

    public List<StockPriceDto> getTopGainers() {
        return stockRepository.findTopGainers()
                .stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    public List<StockPriceDto> getTopLosers() {
        return stockRepository.findTopLosers()
                .stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
    }

    private StockPriceDto convertToDto(Stock stock) {
        return new StockPriceDto(
                stock.getSymbol(),
                stock.getCompanyName(),
                stock.getCurrentPrice(),
                stock.getPreviousClose(),
                stock.getChangeAmount(),
                stock.getChangePercentage(),
                stock.getLastUpdated(),
                stock.getDayHigh(),
                stock.getDayLow(),
                stock.getVolume()
        );
    }
} 