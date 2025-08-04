package com.cognizant.vibecoding.stocktrading.repository;

import com.cognizant.vibecoding.stocktrading.model.Stock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface StockRepository extends JpaRepository<Stock, Long> {
    
    Optional<Stock> findBySymbol(String symbol);
    
    @Query("SELECT s FROM Stock s ORDER BY s.lastUpdated DESC")
    List<Stock> findAllOrderByLastUpdatedDesc();
    
    @Query("SELECT s FROM Stock s WHERE s.changePercentage > 0 ORDER BY s.changePercentage DESC")
    List<Stock> findTopGainers();
    
    @Query("SELECT s FROM Stock s WHERE s.changePercentage < 0 ORDER BY s.changePercentage ASC")
    List<Stock> findTopLosers();
} 