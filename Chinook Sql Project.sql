USE chinook;
-- Foreign key relationship
-- Customer to Employee
ALTER TABLE customer
ADD CONSTRAINT fk_customer_supportrep_new
FOREIGN KEY (support_rep_id)
REFERENCES employee(employee_id);

-- Employee to Employee
ALTER TABLE employee
ADD CONSTRAINT fk_employee_manager
FOREIGN KEY (reports_to) REFERENCES employee(employee_id);

-- Album to Artist
ALTER TABLE album
ADD CONSTRAINT fk_album_artist
FOREIGN KEY (artist_id) REFERENCES artist(artist_id);

-- Track to Album
ALTER TABLE track
ADD CONSTRAINT fk_track_album
FOREIGN KEY (album_id) REFERENCES album(album_id);

-- Track to Genre 
ALTER TABLE track
ADD CONSTRAINT fk_track_genre
FOREIGN KEY (genre_id) REFERENCES genre(genre_id);

-- Track to Media_Type
ALTER TABLE track
ADD CONSTRAINT fk_track_media
FOREIGN KEY (media_type_id) REFERENCES media_type(media_type_id);

-- Invoice to Customer
ALTER TABLE invoice
ADD CONSTRAINT fk_invoice_customer
FOREIGN KEY (customer_id) REFERENCES customer(customer_id);

-- Invoice_Line to Invoice 
ALTER TABLE invoice_line
ADD CONSTRAINT fk_invoiceline_invoice
FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id);

-- Invoice_Line to Track
ALTER TABLE invoice_line
ADD CONSTRAINT fk_invoiceline_track
FOREIGN KEY (track_id) REFERENCES track(track_id);

-- Playlist_Track to Playlist
ALTER TABLE playlist_track
ADD CONSTRAINT fk_playlisttrack_playlist
FOREIGN KEY (playlist_id) REFERENCES playlist(playlist_id);

-- Playlist_Track to Track
ALTER TABLE playlist_track
ADD CONSTRAINT fk_playlisttrack_track
FOREIGN KEY (track_id) REFERENCES track(track_id);


-- Objective Question 
-- 1.	Does any table have missing values or duplicates? If yes how would you handle it ?
-- answer : For Missing Values Queries like that 
SELECT 
   SUM(CASE WHEN first_name IS NULL THEN 1 ELSE 0 END) AS missing_first_name,
   SUM(CASE WHEN last_name IS NULL THEN 1 ELSE 0 END) AS missing_last_name,
   SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS missing_email,
   SUM(CASE WHEN support_rep_id IS NULL THEN 1 ELSE 0 END) AS missing_support_rep
FROM customer;
-- For Duplicates Queries like that
SELECT email, COUNT(*) 
FROM customer
GROUP BY email
HAVING COUNT(*) > 1;

-- 2.	Find the top-selling tracks and top artist in the USA and identify their most famous genres.
-- top 5 tracks by revenue
SELECT distinct t.name AS Track_Name,
       a.title AS Album_Title,
       SUM(il.unit_price * il.quantity) AS Total_Revenue
FROM invoice_line il
JOIN track t ON il.track_id = t.track_id
JOIN album a ON t.album_id = a.album_id
JOIN artist ar ON a.artist_id = ar.artist_id
GROUP BY t.track_id, t.name, a.title
ORDER BY Total_Revenue DESC
LIMIT 5;

-- top 5 artist by total sales
SELECT ar.name AS Artist_Name,
       SUM(il.unit_price * il.quantity) AS Total_Revenue,
       COUNT(DISTINCT t.track_id) AS Number_of_Tracks_Sold
FROM artist ar
JOIN album a ON ar.artist_id = a.artist_id
JOIN track t ON a.album_id = t.album_id
JOIN invoice_line il ON t.track_id = il.track_id
GROUP BY ar.artist_id, ar.name
ORDER BY Total_Revenue DESC
LIMIT 5;


-- 3.	What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?

SELECT customer_id,first_name,last_name,
 CONCAT(
    COALESCE(country, ''),
    ',',
    COALESCE(state, ''),
    ',',
    COALESCE(city, '')
) AS location
FROM customer;

-- 4.	Calculate the total revenue and number of invoices for each country, state, and city:

SELECT billing_country, billing_state, billing_city,
       COUNT(*) AS num_invoices,
       SUM(total) AS total_revenue
FROM invoice
GROUP BY billing_country, billing_state, billing_city
ORDER BY total_revenue DESC;

-- 5.	Find the top 5 customers by total revenue in each country

SELECT customer_id,customer_name, country, total_revenue
FROM (
   SELECT c.customer_id,concat(c.first_name,' ',c.last_name) as customer_name, i.billing_country AS country,
          SUM(i.total) AS total_revenue,
          RANK() OVER (PARTITION BY i.billing_country ORDER BY SUM(i.total) DESC) AS rnk
   FROM customer c
   JOIN invoice i ON c.customer_id = i.customer_id
   GROUP BY c.customer_id, i.billing_country
) ranked
WHERE rnk <= 5;

-- 6.	Identify the top-selling track for each customer

SELECT customer_id, track_name, total_sales
FROM (
    SELECT c.customer_id,
           t.name AS track_name,
           SUM(il.unit_price * il.quantity) AS total_sales,
           ROW_NUMBER() OVER (
               PARTITION BY c.customer_id
               ORDER BY SUM(il.unit_price * il.quantity) DESC
           ) AS rn
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    GROUP BY c.customer_id, t.track_id, t.name
) ranked
WHERE rn = 1;

-- 7.	Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?

SELECT c.customer_id,
       COUNT(i.invoice_id) AS purchase_frequency,
       ROUND(AVG(i.total),2) AS avg_order_value,
       SUM(i.total) AS lifetime_value
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id
ORDER BY lifetime_value DESC;

-- 8.	What is the customer churn rate?

WITH last_date AS (
    SELECT MAX(invoice_date) AS max_date FROM invoice
),
active_customers AS (
    SELECT DISTINCT c.customer_id
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN last_date ld
    WHERE i.invoice_date >= DATE_SUB(ld.max_date, INTERVAL 6 MONTH)
),
previous_customers AS (
    SELECT DISTINCT c.customer_id
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN last_date ld
    WHERE i.invoice_date < DATE_SUB(ld.max_date, INTERVAL 6 MONTH)
)
SELECT 
    (SELECT COUNT(*) FROM previous_customers) AS previously_active,
    (SELECT COUNT(*) FROM active_customers) AS still_active,
    (
      (SELECT COUNT(*) FROM previous_customers) -
      (SELECT COUNT(*) FROM active_customers)
    ) * 100.0 / (SELECT COUNT(*) FROM previous_customers) AS churn_rate_percent;
    
  -- 9.	Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.

SELECT g.name AS genre_name, 
       a.name AS artist_name,
       SUM(il.unit_price * il.quantity) AS sales,
       SUM(il.unit_price * il.quantity) * 100.0 / 
         (SELECT SUM(il2.unit_price * il2.quantity)
          FROM invoice_line il2
          JOIN invoice i2 ON il2.invoice_id = i2.invoice_id
          WHERE i2.billing_country = 'USA') AS pct_sales
FROM invoice_line il
JOIN invoice i ON il.invoice_id = i.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN artist a ON al.artist_id = a.artist_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE i.billing_country = 'USA'
GROUP BY g.name, a.name
ORDER BY pct_sales DESC;

 -- 10.	Find customers who have purchased tracks from at least 3 different genres

SELECT c.customer_id, c.first_name, c.last_name, COUNT(DISTINCT g.genre_id) AS genre_count
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
GROUP BY c.customer_id
HAVING COUNT(DISTINCT g.genre_id) >= 3;

 -- 11.	Rank genres based on their sales performance in the USA

WITH genre_sales AS (
    SELECT g.name AS genre_name,
           SUM(il.unit_price * il.quantity) AS sales
    FROM invoice_line il
    JOIN invoice i ON il.invoice_id = i.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.name
)
SELECT genre_name,
       sales,
       RANK() OVER (ORDER BY sales DESC) AS rnk
FROM genre_sales;

-- 12.	Identify customers who have not made a purchase in the last 3 months
SELECT c.customer_id, c.first_name, c.last_name
FROM customer c
LEFT JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id
HAVING MAX(i.invoice_date) < DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
   OR MAX(i.invoice_date) IS NULL;

-- SUBJECTIVE QUESTION

-- 1.Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.

WITH genre_sales AS (
  SELECT 
    g.name AS genre_name,
    ar.name AS artist_name,
    al.title AS album_title,
    SUM(il.unit_price * il.quantity) AS total_sales,
    ROW_NUMBER() OVER (PARTITION BY g.genre_id ORDER BY SUM(il.unit_price * il.quantity) asc) AS rn
  FROM invoice_line il
  JOIN invoice i ON il.invoice_id = i.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN album al ON t.album_id = al.album_id
  JOIN artist ar ON al.artist_id = ar.artist_id
  JOIN genre g ON t.genre_id = g.genre_id
  WHERE i.billing_country = 'USA'
  GROUP BY g.name, ar.name, al.title, g.genre_id
)
SELECT * 
FROM genre_sales
WHERE rn = 1
ORDER BY total_sales DESC
LIMIT 3;

-- 2.Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.

WITH non_usa_genre_sales AS (
    SELECT 
        i.billing_country,
        g.name AS genre_name,
        SUM(il.unit_price * il.quantity) AS total_sales
    FROM invoice_line il
    JOIN invoice i ON il.invoice_id = i.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE i.billing_country <> 'USA'
    GROUP BY i.billing_country, g.name
),
ranked_non_usa_genres AS (
    SELECT 
        billing_country,
        genre_name,
        total_sales,
        RANK() OVER (PARTITION BY billing_country ORDER BY total_sales DESC) AS genre_rank
    FROM non_usa_genre_sales
),
top_non_usa_genres AS (
    SELECT billing_country, genre_name, total_sales
    FROM ranked_non_usa_genres
    WHERE genre_rank = 1
),
usa_genres AS (
    SELECT 
        g.name AS genre_name,
        SUM(il.unit_price * il.quantity) AS total_sales,
        RANK() OVER (ORDER BY SUM(il.unit_price * il.quantity) DESC) AS genre_rank
    FROM invoice_line il
    JOIN invoice i ON il.invoice_id = i.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.name
)
SELECT 
    'Non-USA' AS region,
    billing_country AS country,
    genre_name,
    total_sales
FROM top_non_usa_genres
UNION ALL
SELECT 
    'USA' AS region,
    'USA' AS country,
    genre_name,
    total_sales
FROM usa_genres
WHERE genre_rank <= 3  
ORDER BY region, total_sales DESC;

-- 3.Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?

WITH customer_first_purchase AS (
    SELECT 
        c.customer_id,
        MIN(i.invoice_date) AS first_purchase_date
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),
customer_type AS (
    SELECT 
        c.customer_id,
        CASE 
            WHEN DATEDIFF(CURDATE(), f.first_purchase_date) <= 180 THEN 'New Customer'
            ELSE 'Long-Term Customer'
        END AS customer_category
    FROM customer c
    JOIN customer_first_purchase f ON c.customer_id = f.customer_id
),
customer_behavior AS (
    SELECT 
        i.customer_id,
        COUNT(DISTINCT i.invoice_id) AS total_orders,                  
        SUM(il.quantity) / COUNT(DISTINCT i.invoice_id) AS avg_basket_size, 
        SUM(il.unit_price * il.quantity) / COUNT(DISTINCT i.invoice_id) AS avg_spend_per_order
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY i.customer_id
)
SELECT 
    ct.customer_category,
    ROUND(AVG(cb.total_orders), 2) AS avg_order_frequency,
    ROUND(AVG(cb.avg_basket_size), 2) AS avg_basket_size,
    ROUND(AVG(cb.avg_spend_per_order), 2) AS avg_spending
FROM customer_behavior cb
JOIN customer_type ct ON cb.customer_id = ct.customer_id
GROUP BY ct.customer_category;

-- 4.Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives?

WITH track_sales AS (
    SELECT 
        i.invoice_id,
        t.track_id,
        g.name AS genre_name,
        ar.name AS artist_name,
        al.title AS album_title
    FROM invoice_line il
    JOIN invoice i ON il.invoice_id = i.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist ar ON al.artist_id = ar.artist_id
),
genre_pairs AS (
    SELECT 
        a.genre_name AS genre_1,
        b.genre_name AS genre_2
    FROM track_sales a
    JOIN track_sales b 
        ON a.invoice_id = b.invoice_id 
        AND a.genre_name < b.genre_name  
)
SELECT 
    genre_1,
    genre_2,
    COUNT(*) AS times_bought_together
FROM genre_pairs
GROUP BY genre_1, genre_2
ORDER BY times_bought_together DESC
LIMIT 5;

-- 5.Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors?

WITH last_purchase AS (
    SELECT MAX(invoice_date) AS max_date FROM invoice
),
customer_stats AS (
    SELECT 
        c.customer_id,
        i.billing_country,
        COUNT(DISTINCT i.invoice_id) AS total_orders,
        SUM(il.unit_price * il.quantity) AS total_spent,
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY c.customer_id, i.billing_country
),
customer_churn AS (
    SELECT 
        cs.billing_country,
        cs.customer_id,
        cs.total_orders,
        cs.total_spent,
        CASE 
            WHEN cs.last_purchase_date < DATE_SUB(lp.max_date, INTERVAL 6 MONTH)
            THEN 1 ELSE 0
        END AS churned
    FROM customer_stats cs
    CROSS JOIN last_purchase lp
),
region_summary AS (
    SELECT 
        billing_country,
        COUNT(DISTINCT customer_id) AS total_customers,
        ROUND(SUM(total_spent), 2) AS total_revenue,
        ROUND(AVG(total_spent / total_orders), 2) AS avg_order_value,
        ROUND(SUM(churned) * 100.0 / COUNT(*), 2) AS churn_rate_percent
    FROM customer_churn
    GROUP BY billing_country
)
SELECT 
    billing_country AS region,
    total_customers,
    total_revenue,
    avg_order_value,
    churn_rate_percent
FROM region_summary
ORDER BY total_revenue DESC;

-- 6.Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?

WITH recent_invoices AS (
    SELECT 
        customer_id,
        MAX(invoice_date) AS last_purchase_date,
        COUNT(*) AS total_invoices,
        SUM(total) AS total_spent
    FROM invoice
    GROUP BY customer_id
),
invoice_trend AS (
    SELECT 
        ri.customer_id,concat(c.first_name,' ',c.last_name) as customer_name,
        ri.last_purchase_date,
        ri.total_invoices,
        ri.total_spent,
        c.city,
        c.country,
        c.support_rep_id,
        CASE 
    WHEN ri.total_invoices = 1 THEN 'One-time Buyer'
    WHEN ri.total_spent < 50 THEN 'Low Spender'
    WHEN ri.last_purchase_date < DATE_SUB(NOW(), INTERVAL 6 MONTH) THEN 'Inactive'
    ELSE 'Active'
END AS risk_segment

    FROM recent_invoices ri
    JOIN customer c ON ri.customer_id = c.customer_id
)
SELECT 
    customer_id,customer_name,
    city,
    country,
    support_rep_id,
    total_invoices,
    total_spent,
    last_purchase_date,
    risk_segment
FROM invoice_trend
WHERE risk_segment IN ('One-time Buyer', 'Low Spender', 'Inactive')
ORDER BY last_purchase_date ASC;

-- 7.Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?
SELECT 
  customer_id,
  MIN(invoice_date) AS first_purchase,
  MAX(invoice_date) AS last_purchase,
  COUNT(*) AS purchase_count,
  SUM(total) AS lifetime_value,
  DATEDIFF(MAX(invoice_date), MIN(invoice_date)) AS tenure_days
FROM invoice
GROUP BY customer_id;

-- 10.How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?

-- To add a new column to an existing table, we use the ALTER TABLE statement with the ADD COLUMN clause.
use chinook;

ALTER TABLE album
ADD COLUMN ReleaseYear INTEGER;

-- 11.Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information.

WITH CustomerStats AS (
    SELECT 
        c.customer_id,
        c.country,
        SUM(i.total) AS total_spent,
        SUM(il.quantity) AS total_tracks_purchased
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY c.customer_id, c.country
)

SELECT 
    country,
    COUNT(customer_id) AS Number_of_Customers,
    ROUND(AVG(total_spent), 2) AS Avg_Total_Spent_Per_Customer,
    ROUND(AVG(total_tracks_purchased), 2) AS Avg_Tracks_Purchased_Per_Customer
FROM CustomerStats
GROUP BY country
ORDER BY Avg_Total_Spent_Per_Customer DESC;

-- 8.If data on promotional campaigns (discounts, events, email marketing) is available, how could you measure their impact on customer acquisition, retention, and overall sales?

-- Step 1: Calculate first purchase date for every customer
WITH FirstPurchase AS (
    SELECT 
        customer_id,
        MIN(invoice_date) AS first_purchase_date
    FROM invoice
    GROUP BY customer_id
),

-- Step 2: Classify customers based on when they first purchased
CustomerGroups AS (
    SELECT 
        f.customer_id,
        CASE 
            WHEN f.first_purchase_date < '2022-01-01' THEN 'Existing Before Campaign'
            WHEN f.first_purchase_date BETWEEN '2022-01-01' AND '2022-03-31' THEN 'Acquired During Campaign'
            ELSE 'Acquired After Campaign'
        END AS customer_status
    FROM FirstPurchase f
),

-- Step 3: Summarize sales by period (before, during, after)
SalesSummary AS (
    SELECT 
        CASE 
            WHEN invoice_date < '2022-01-01' THEN 'Before Campaign'
            WHEN invoice_date BETWEEN '2022-01-01' AND '2022-03-31' THEN 'During Campaign'
            ELSE 'After Campaign'
        END AS period,
        SUM(total) AS total_sales
    FROM invoice
    GROUP BY period
),

-- Step 4: Find repeat (retained) customers
RetentionStats AS (
    SELECT 
        c.customer_id,
        COUNT(i.invoice_id) AS purchase_count
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
    HAVING COUNT(i.invoice_id) > 1
)

-- Step 5: Combine and display summarized metrics
SELECT 
    (SELECT COUNT(DISTINCT customer_id) 
     FROM CustomerGroups WHERE customer_status = 'Acquired During Campaign') AS New_Customers_During_Campaign,

    (SELECT COUNT(customer_id) FROM RetentionStats) AS Retained_Customers,

    (SELECT total_sales FROM SalesSummary WHERE period = 'Before Campaign') AS Sales_Before_Campaign,
    (SELECT total_sales FROM SalesSummary WHERE period = 'During Campaign') AS Sales_During_Campaign,
    (SELECT total_sales FROM SalesSummary WHERE period = 'After Campaign') AS Sales_After_Campaign;











