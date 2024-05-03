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


# Base de Datos Vectorial
Para esta primera parte cargaremos un conjunto de datos sobre catas de vinos 🍇 originalmente disponible en [Kaggle](https://www.kaggle.com/datasets/zynicide/wine-reviews).

[Aquí](./data) tenemos preparadas unas versiones de 500 y 5K registros para hacer pruebas.

Vamos a trabajar principalmente utilizando SQL y después añadiremos algunos métodos utilizando VSCode.

Puedes conectarte por SQL utilizando el [Explorador SQL](http://localhost:52773/csp/sys/exp/%25CSP.UI.Portal.SQL.Home.zen?$NAMESPACE=USER) del Portal o directamente utilizando cualquier herramienta como [DBeaver](https://dbeaver.io).

## Crear tabla
InterSystems IRIS nos permite almacenar vectores y utilizar operaciones para realizar búsquedas ([aquí](https://docs.intersystems.com/iris20241/csp/docbook/Doc.View.cls?KEY=GSQL_vecsearch) tenéis más información.)

Como primer paso, crearemos una tabla directamente en SQL para cargar el conjunto de datos 🍇 y además añadiremos una columna que será la encargada de almacenar el vector correspondiente a la descripción.

```sql
CREATE TABLE webinar_data.WineReviews (
        uid INT,                       
        country VARCHAR(255),
        description VARCHAR(2000),                 -- descripción en texto libre
        designation VARCHAR(255),
        points INT,
        price DOUBLE,
        province VARCHAR(255),
        region VARCHAR(255),
        variety VARCHAR(255),
        description_vector VECTOR(DOUBLE, 384)    -- vector correspondiente a la descripción
)
```

## Cargar datos de prueba

Cargamos a continuación los CSV de prueba. Utilizamos la funcionalidad [LOAD DATA](https://docs.intersystems.com/iris20241/csp/docbook/Doc.View.cls?KEY=RSQL_loaddata) que directamente nos ahorra muchísimo trabajo 🙂 

```sql
LOAD DATA FROM FILE '/app/data/wine-reviews-5K.csv'
INTO webinar_data.WineReviews (uid,country,description,designation,points,price,province,region,variety)
VALUES (num,country,description,designation,points,price,province,region1,variety)
USING {"from":{"file":{"header":true, "charset": "UTF-8"}}}
```

Echemos un vistazo a los datos que se han cargado:

```sql
SELECT country, count(*) total
FROM webinar_data.WineReviews
GROUP BY country
ORDER BY count(*) DESC
```

## Calcular Vectores (encoding) para los datos de prueba

Como has podido ver, la columna "description_vector" está vacía. No tenemos vectores calculados aún.

Vamos a calcular vectores utilizando un modelo pre-entrenado llamado [all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2). Este modelo calculará vectores de 384 dimensiones por cada descripción que le pasemos.

Llamaremos a este modelo a través de Python embebido en IRIS.

En VS Code:
* Conecta con la instancia de IRIS
* Localiza la clase `webinar.data.WineReviews` en el servidor.
* Esta clase se corresponde con la definición que acabamos de hacer en SQL. InterSystems IRIS mantiene automáticamente la correspondencia entre clases / objetos y tablas SQL.
* Click dereecho y "Exportar". Así podrás editar la clase en tu VSCode.

Añade a continuación el siguiente método y compila la clase. Cuando llames a este método, actualizará cada fila de `webinar.data.WineReviews` con el vector calculado correspondiente a la descripción en la columna `description_vector` utilizando el modelo all-MiniLM-L6-v2.

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

Llama al método que acabas de añadir a la clase desde una sesión interactiva con IRIS en el [WebTerminal](http://localhost:52773/terminal/). La ejecución del método tardará unos minutos:

```objectscript
do ##class(webinar.data.WineReviews).AddEncodings()
```

Después de ejecutar el método, vuelve a echar un vistazo a tus datos. ¿Ya tienes la columna `description_vector` rellena?


## Añadir método para obtener encodings 

Hemos añadido los encodings (vectores) de la columna `description` en la columna `description_vector`. Necesitaremos además una manera de calcular el encoding correspondiente a cualquier cadena que queramos.

Añade en `webinar.data.WineReviews` el siguiente método. Este método podremos invocarlo directamente desde SQL como un procedimiento.

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

A continuación puedes probar el método directamente desde SQL:

```sql
SELECT webinar_data.WineReviews_GetEncoding('blackberry')
```

## Realizar búsquedas de vectores similares

IRIS incorpora dos operaciones [VECTOR_DOT_PRODUCT](https://docs.intersystems.com/iris20241/csp/docbook/Doc.View.cls?KEY=RSQL_vectordotproduct) y [VECTOR_COSINE](https://docs.intersystems.com/iris20241/csp/docbook/Doc.View.cls?KEY=RSQL_vectorcosine) que podemos utilizar para buscar vectores similares.

Los vectores similares en el espacio vectorial del encoding, tendrán significados parecidos.

Podemos buscar directamente en SQL y combinar la búsqueda con cualquier otro criterio que nos queramos:

```sql
SELECT TOP 5 uid, country, designation, region, variety, description FROM webinar_data.WineReviews 
WHERE country in ('Spain', 'France') 
ORDER BY VECTOR_DOT_PRODUCT(description_vector, TO_VECTOR(webinar_data.WineReviews_GetEncoding('blackberry'))) DESC
```

## Servicio REST que utiliza búsqueda de vectores

En [WineReviewService.cls](./src/webinar/api/WineReviewService.cls) tienes un servicio REST que puedes compilar directamente y podrás probar en IRIS.

El servicio recibe una descripción y realiza una búsqueda de descripciones similares (vectores) en la tabla con la que has trabajado.

En [webinar.postman_collection.json](./webinar.postman_collection.json) tienes un proyecto Postman con peticiones configuradas para probarlo.

<img src="img/rest-wineservice.png" width="600" />

# Aplicación IA Generativa: combinar LLM con base de datos Vectorial



