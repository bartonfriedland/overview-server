package org.overviewproject.util

import org.overviewproject.util.DocumentSetCreationJobStateDescription._

object ExceptionStatusMessage {

  def apply(t: Throwable): String = t  match {
    case e: java.lang.OutOfMemoryError => OutOfMemory.toString
    case _ => WorkerError.toString
  }
}