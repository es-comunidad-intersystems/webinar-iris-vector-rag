
CREATE TABLE webinar_data.WineReviews (
        uid INT,
        country VARCHAR(255),
        description VARCHAR(2000),
        designation VARCHAR(255),
        points INT,
        price DOUBLE,
        province VARCHAR(255),
        region VARCHAR(255),
        variety VARCHAR(255),
        description_vector VECTOR(DOUBLE, 384)
)


LOAD DATA FROM FILE '/app/data/wine-reviews-5K.csv'
INTO webinar_data.WineReviews (uid,country,description,designation,points,price,province,region,variety)
VALUES (num,country,description,designation,points,price,province,region1,variety)
USING {"from":{"file":{"header":true, "charset": "UTF-8"}}}


SELECT country, count(*) total
FROM webinar_data.WineReviews
GROUP BY country
ORDER BY count(*) DESC


SELECT webinar_data.WineReviews_GetEncoding('citrus flavors')


-- try: blackberry, walnut, citrus flavors
SELECT TOP 5 uid, country, designation, region, variety, description FROM webinar_data.WineReviews 
WHERE country in ('Spain', 'France') 
ORDER BY VECTOR_DOT_PRODUCT(description_vector, TO_VECTOR(webinar_data.WineReviews_GetEncoding('citrus flavors'))) DESC


