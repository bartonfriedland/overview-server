package controllers

import play.api.data._
import play.api.data.Forms._
import play.api.mvc.{Action,Controller}
import models.DocumentSetCreationJob
import models.DocumentSetCreationJob

object DocumentSet extends Controller {
    def index(documentSetId: Long) = Action {
        Ok(views.html.DocumentSet.index())
    }
    
    def newDocumentSet() = Action { implicit request =>
      val queryForm = Form(
          mapping(
              "query" -> text
          ) ((query) => new DocumentSetCreationJob(query))
            ((job: DocumentSetCreationJob) => Some((job.query)))
      ) 
       
      val documentSetCreationJob: DocumentSetCreationJob = queryForm.bindFromRequest.get
      documentSetCreationJob.save
      
      val documentSet = new models.DocumentSet()
      documentSet.query = documentSetCreationJob.query
      documentSet.save
      
      
      Redirect(routes.Application.showDocumentSets())
    }
}
