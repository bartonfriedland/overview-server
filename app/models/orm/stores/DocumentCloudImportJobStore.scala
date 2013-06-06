package models.orm.stores

import org.overviewproject.tree.orm.{ DocumentSet, DocumentSetCreationJob, DocumentSetCreationJobState }
import org.overviewproject.tree.{ DocumentSetCreationJobType, Ownership }
import models.orm.DocumentSetUser 
import models.DocumentCloudImportJob

object DocumentCloudImportJobStore {
  /** Creates a new DocumentCloudImportJob in the database.
    *
    * FIXME this inserts rows in DocumentSet and DocumentSetUser. Both stores
    * should be left alone. (First we need to make the worker add those rows.)
    */
  def insert(job: DocumentCloudImportJob) : DocumentSetCreationJob = {
    val documentSet = DocumentSetStore.insertOrUpdate(DocumentSet(
      title=job.title,
      query=Some(job.query)
    ))
    DocumentSetUserStore.insertOrUpdate(DocumentSetUser(
      documentSetId=documentSet.id,
      userEmail=job.ownerEmail,
      role=Ownership.Owner
    ))
    DocumentSetCreationJobStore.insertOrUpdate(DocumentSetCreationJob(
      documentSetId=documentSet.id,
      state=DocumentSetCreationJobState.NotStarted,
      jobType=DocumentSetCreationJobType.DocumentCloud,
      documentcloudUsername=job.credentials.map(_.username),
      documentcloudPassword=job.credentials.map(_.password),
      splitDocuments=job.splitDocuments
    ))
  }
}
