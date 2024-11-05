import React, { useState, useEffect } from "react";
import axios from "axios";

function App() {
  const [stocks, setStocks] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      const symbols = ["AAPL", "GOOGL", "MSFT"];
      const results = await Promise.all(
        symbols.map(symbol => 
          axios.get(`/api/v1/prices/${symbol}`)
        )
      );
      setStocks(results.map(r => r.data));
    };

    fetchData();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div>
      <h1>RTSAP Dashboard</h1>
      {stocks.map((stockData, index) => (
        <div key={index}>
          <h2>{stockData[0]?.symbol}</h2>
          <p>Latest Price: {stockData[0]?.avg_price}</p>
        </div>
      ))}
    </div>
  );
}
