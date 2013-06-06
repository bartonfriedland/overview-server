package views.json.Tree


import helpers.TestTag
import models.core._
import org.specs2.mutable.Specification
import play.api.libs.json.Json.toJson
import org.overviewproject.tree.orm.SearchResult

class showSpec extends Specification {
  
  "Tree view generated Json" should {
    
    "contain all nodes" in {
      val documentIds = DocumentIdList(List(10, 20, 30), 43)
      
      val nodes = List(
          Node(1l, "description", List(2, 3), documentIds, Map()),
          Node(2l, "description", List(4, 5, 6), documentIds, Map()), 
          Node(3l, "description", List(7), documentIds, Map()) 
      )
      
      val dummyDocuments = List[Document]()
      val dummyTags = List[TestTag]()
      val dummySearchResult = List[SearchResult]()
      
      val treeJson = show(nodes, dummyDocuments, dummyTags, dummySearchResult).toString
      
      treeJson must /("nodes") */("id" -> 1)
      treeJson must /("nodes") */("id" -> 2)
      treeJson must /("nodes") */("id" -> 3)
    }
    
    "contain all documents" in {
      val dummyNodes = List[Node]()
      val documents = List(
    	Document(10l, "description", Some("title"), Some("documentCloudId"), Seq(), Seq(22l)),
    	Document(20l, "description", Some("title"), Some("documentCloudId"), Seq(), Seq(22l)),
    	Document(30l, "description", Some("title"), Some("documentCloudId"), Seq(), Seq(22l))
      )
      val dummyTags = List[TestTag]()
      val dummySearchResult = List[SearchResult]()
      
      val treeJson = show(dummyNodes, documents, dummyTags, dummySearchResult).toString
      
      treeJson must /("documents") */("id" -> 10l)
      treeJson must /("documents") */("id" -> 20l)
      treeJson must /("documents") */("id" -> 30l)
    }
    
    "contain tags" in {
      val dummyNodes = List[Node]()
      val dummyDocuments = List[Document]()
      val tags = List(
        TestTag(5l, "tag1", None, DocumentIdList(Seq(), 0)),
        TestTag(15l, "tag2", None, DocumentIdList(Seq(), 0))
      )
      val dummySearchResult = List[SearchResult]()
      
      val treeJson = show(dummyNodes, dummyDocuments, tags, dummySearchResult).toString
      
      treeJson must /("tags") */("id" -> 5l)
      treeJson must /("tags") */("id" -> 15l)
    }
  }
  
  "JsonNode" should {
    import views.json.Tree.show.JsonNode
    
    "write node attributes" in {
      val documentIds = DocumentIdList(List(10, 20, 30), 45)
      val tagCounts = Map(("3" -> 22l), ("4" -> 555l))
      val node = Node(1, "node", List(4, 5, 6), documentIds, tagCounts)
      
      val nodeJson = toJson(node).toString
      
      nodeJson must /("id" -> 1)
      nodeJson must /("description" -> "node")
      nodeJson must contain("\"children\":" + List(4, 5, 6).mkString("[", ",", "]"))
      nodeJson must =~ ("doclist.*docids.*n".r)
      
      nodeJson must contain(""""tagcounts":{"3":22,"4":555}""")
    }
  }

}
