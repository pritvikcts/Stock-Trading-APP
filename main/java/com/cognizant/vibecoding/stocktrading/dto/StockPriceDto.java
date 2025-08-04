package com.cognizant.vibecoding.stocktrading.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class StockPriceDto {
    private String symbol;
    private String companyName;
    private BigDecimal currentPrice;
    private BigDecimal previousClose;
    private BigDecimal changeAmount;
    private BigDecimal changePercentage;
    private LocalDateTime lastUpdated;
    private BigDecimal dayHigh;
    private BigDecimal dayLow;
    private Long volume;
} 