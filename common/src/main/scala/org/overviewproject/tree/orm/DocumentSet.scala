package org.overviewproject.tree.orm

import java.sql.Timestamp
import org.squeryl.KeyedEntity
import org.squeryl.annotations.Column
import scala.language.implicitConversions

case class DocumentSet(
  override val id: Long = 0,
  title: String = "",
  query: Option[String] = None,
  @Column("public") isPublic: Boolean = false,
  createdAt: Timestamp = new Timestamp(scala.compat.Platform.currentTime),
  documentCount: Int = 0,
  documentProcessingErrorCount: Int = 0,
  importOverflowCount: Int = 0,

  uploadedFileId: Option[Long] = None) extends KeyedEntity[Long] {

  // https://www.assembla.com/spaces/squeryl/tickets/68-add-support-for-full-updates-on-immutable-case-classes#/followers/ticket:68
  override def isPersisted(): Boolean = (id > 0)
}

object DocumentSet {
  implicit def toLong(documentSet: DocumentSet) = documentSet.id
}
