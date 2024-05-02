Class webinar.api.CervantesService Extends %CSP.REST
{

Parameter HandleCorsRequest = 0;

Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "https://www.intersystems.com/urlmap" ]
{
<Routes>
	<Route Url="/qa" Method="GET" Call="AnswerQuestion" />   
</Routes>
}

ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    set %response.ContentType = "application/json"
    Quit $$$OK
}

ClassMethod AnswerQuestion() As %Status
{
    set ret = $$$OK
    try {
        set question = $get(%request.Data("question",1))
        set k = $get(%request.Data("k",1))

        set rsp = ..AnswerQuestionPython(question, k)
        
        set %response.Status = ..#HTTP200OK
        write { "respuesta": (rsp) }.%ToJSON()

    } catch ex {
        set %response.Status = ..#HTTP400BADREQUEST
        return ex.DisplayString()
    }
    quit ret
}

ClassMethod AnswerQuestionPython(question As %String, k As %Integer) As %String [ Language = python ]
{
    # load OpenAI APIKEY from env
    import os
    from dotenv import load_dotenv, find_dotenv
    _ = load_dotenv('/home/irisowner/.env')

    llm_model = "gpt-3.5-turbo"

    # imports (sample)
    from langchain.docstore.document import Document
    from langchain.document_loaders import TextLoader
    from langchain.text_splitter import CharacterTextSplitter
    from langchain.embeddings.openai import OpenAIEmbeddings

    from langchain.chat_models import ChatOpenAI
    from langchain.prompts import ChatPromptTemplate
    from langchain.chains import LLMChain

    from langchain.output_parsers import ResponseSchema
    from langchain.output_parsers import StructuredOutputParser

    from langchain_iris import IRISVector

    username = 'demo'
    password = 'demo' 
    hostname = 'localhost'
    port = '1972' 
    namespace = 'USER'
    CONNECTION_STRING = f"iris://{username}:{password}@{hostname}:{port}/{namespace}"

    embeddings = OpenAIEmbeddings()

    COLLECTION_NAME = "wikicervantes"

    db = IRISVector(
    embedding_function=embeddings,
    collection_name=COLLECTION_NAME,
    connection_string=CONNECTION_STRING,
    )

    # create llm
    llm = ChatOpenAI(temperature=0.0, model=llm_model)

    rsp_schema = ResponseSchema(
        name="rsp",
        description="response to question",
    )

    # prompt response schema
    response_schemas = [rsp_schema]
    output_parser = StructuredOutputParser.from_response_schemas(response_schemas)
    format_instructions = output_parser.get_format_instructions()

    query_template = """\
    Interprete and evaluate the following question in Spanish: {question}

    {format_instructions}

    Use the following context:
    {context}

    Do not use any other information.
    """

     # build prompt
    from langchain.prompts import PromptTemplate
    QA_CHAIN_PROMPT = PromptTemplate(
        input_variables=["context", "query"],
        partial_variables={"format_instructions": format_instructions},
        template=query_template,
    )

    from langchain.chains import RetrievalQA
    qa_chain = RetrievalQA.from_chain_type(
        llm,
        retriever=db.as_retriever(search_kwargs={"k": k}),
        return_source_documents=True,
        chain_type_kwargs={
            "verbose": False,
            "prompt": QA_CHAIN_PROMPT
        }
    )

    result = qa_chain(question)

    output_dict = output_parser.parse(result["result"])

    return output_dict['rsp']
}

}
