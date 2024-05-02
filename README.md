Aquí encontrarás los ejemplos utilizados en el [Webinar - Base de datos Vectorial y Aplicaciones de IA Generativa](https://comunidadintersystems.com/).

# ¿Qué necesitas?
* [Docker](https://www.docker.com/products/docker-desktop) - para ejecutar [InterSystems IRIS Community](https://www.intersystems.com/products/intersystems-iris/).
* [Postman](https://www.postman.com/downloads/) - para lanzar peticiones REST.


## Instalación
1. Clona o descarga el repositorio desde GitHub
```shell
git clone https://github.com/es-comunidad-intersystems/webinar-iris-vector-rag
cd webinar-iris-vector-rag
```

2. Inicia la instancia [InterSystems IRIS Community](https://www.intersystems.com/products/intersystems-iris/)
```shell
docker compose up
```

3. Con la instancia en marcha, podrás acceder al [Mng. Portal](http://localhost:52773/csp/sys/UtilHome.csp)
* Usuario: `demo`
* Password: `demo`
4. Abre una sesión interactiva utilizando [WebTerminal](http://localhost:52773/terminal/)


# Base de Datos Vectorial

DataSet https://www.kaggle.com/datasets/zynicide/wine-reviews

```sql
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
```

```sql
LOAD DATA FROM FILE '/app/data/wine-reviews-5K.csv'
INTO webinar_data.WineReviews (uid,country,description,designation,points,price,province,region,variety)
VALUES (num,country,description,designation,points,price,province,region1,variety)
USING {"from":{"file":{"header":true, "charset": "UTF-8"}}}
```

```sql
SELECT country, count(*) total
FROM webinar_data.WineReviews
GROUP BY country
ORDER BY count(*) DESC
```

```objectscript
ClassMethod AddEncodings() [ Language = python ]
{
    import iris
    import pandas
    from sentence_transformers import SentenceTransformer

    rs = iris.sql.exec("SELECT uid, description FROM webinar_data.WineReviews")
    df = rs.dataframe()
    
    # Load a pre-trained sentence transformer model. This model's output vectors are of size 384
    model = SentenceTransformer('all-MiniLM-L6-v2')
    
    # Generate embeddings for all descriptions at once. Batch processing makes it faster
    embeddings = model.encode(df['description'].tolist(), normalize_embeddings=True)

    # Add the embeddings to the DataFrame
    df['description_vector'] = embeddings.tolist()

    stmt = iris.sql.prepare("UPDATE webinar_data.WineReviews SET description_vector = TO_VECTOR(?) where uid = ?")
    for index, row in df.iterrows():
        rs = stmt.execute(str(row['description_vector']), row['uid'])
}
```

```objectscript
ClassMethod GetEncoding(sentence As %String) As %String [ Language = python, SqlProc ]
{
    import sentence_transformers
    # create the model and form the embeddings
    model = sentence_transformers.SentenceTransformer('all-MiniLM-L6-v2')
    embeddings = model.encode(sentence, normalize_embeddings=True).tolist() # Convert search phrase into a vector
    # convert the embeddings to a string
    return str(embeddings)
}
```

```sql
SELECT webinar_data.WineReviews_GetEncoding('blackberry')
```

```sql
SELECT TOP 5 uid, country, designation, region, variety, description FROM webinar_data.WineReviews 
WHERE country in ('Spain', 'France') 
ORDER BY VECTOR_DOT_PRODUCT(description_vector, TO_VECTOR(webinar_data.WineReviews_GetEncoding('blackberry'))) DESC
```

