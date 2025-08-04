package com.cognizant.vibecoding.stocktrading.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "stocks")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Stock {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String symbol;
    
    @Column(nullable = false)
    private String companyName;
    
    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal currentPrice;
    
    @Column(precision = 10, scale = 2)
    private BigDecimal previousClose;
    
    @Column(precision = 10, scale = 2)
    private BigDecimal changeAmount;
    
    @Column(precision = 5, scale = 2)
    private BigDecimal changePercentage;
    
    @Column(nullable = false)
    private LocalDateTime lastUpdated;
    
    @Column
    private BigDecimal dayHigh;
    
    @Column
    private BigDecimal dayLow;
    
    @Column
    private Long volume;
    
    public Stock(String symbol, String companyName, BigDecimal currentPrice) {
        this.symbol = symbol;
        this.companyName = companyName;
        this.currentPrice = currentPrice;
        this.lastUpdated = LocalDateTime.now();
    }
} 