package org.overviewproject.runner.commands

import java.io.File

class PostgresCommand(override val argv: Seq[String]) extends Command(Seq(), argv) {
  def withSubArgs(subArgs: Seq[String]) : PostgresCommand = new PostgresCommand(argv ++ subArgs)
}

object PostgresCommand {
  val UnixStandardSearchPaths : Iterable[String] = Seq(
    // Standard systems
    "/usr/sbin",
    "/usr/local/sbin",
    // Ubuntu
    "/usr/lib/postgresql/9.3/bin",
    "/usr/lib/postgresql/9.2/bin",
    "/usr/lib/postgresql/9.1/bin",
    "/usr/lib/postgresql/9.0/bin",
    // Fedora, according to http://koji.fedoraproject.org/koji/rpminfo?rpmID=4676802
    // Mac OS X Server default, starting 10.7, according to http://stackoverflow.com/questions/6770649/repairing-postgresql-after-upgrading-to-osx-10-7-lion
    "/usr/bin",
    // Homebrew, according to http://stackoverflow.com/questions/6770649/repairing-postgresql-after-upgrading-to-osx-10-7-lion
    "/usr/local/bin",
    // Postgres default
    "/usr/local/pgsql/bin",
    // Postgres suggestion on http://www.postgresql.org/docs/9.2/static/install-procedure.html
    "/opt/local/lib",
    // MacPorts, according to https://trac.macports.org/browser/trunk/dports/databases/postgresql91/Portfile
    "/opt/local/lib/postgresql93/bin",
    "/opt/local/lib/postgresql92/bin",
    "/opt/local/lib/postgresql91/bin",
    "/opt/local/lib/postgresql90/bin",
    // Postgres.app, as per http://postgresapp.com/documentation
    "/Applications/Postgres.app/Contents/MacOS/bin",
    // Fink, according to http://pdb.finkproject.org/pdb/package.php/postgresql92
    "/sw/opt/postgresql-9.3/bin",
    "/sw/opt/postgresql-9.2/bin",
    "/sw/opt/postgresql-9.1/bin",
    "/sw/opt/postgresql-9.0/bin",
    // EnterpriseDB, according to http://www.enterprisedb.com/resources-community/pginst-guide
    "/opt/PostgreSQL/9.3/bin",
    "/opt/PostgreSQL/9.2/bin",
    "/opt/PostgreSQL/9.1/bin",
    "/opt/PostgreSQL/9.0/bin",
    "/Library/PostgreSQL/9.3/bin",
    "/Library/PostgreSQL/9.2/bin",
    "/Library/PostgreSQL/9.1/bin",
    "/Library/PostgreSQL/9.0/bin"
  )

  val RequiredCommands : Seq[String] = Seq("initdb", "postgres")

  trait Filesystem {
    def isFileExecutable(path: String) : Boolean
    def programFilesPath: Option[String]
    def envPaths: Seq[String]
  }

  object Filesystem extends Filesystem {
    override def isFileExecutable(path: String) : Boolean = new File(path).canExecute
    override def programFilesPath = sys.env.get("PROGRAM_FILES")
    override def envPaths: Seq[String] = {
      sys.env.getOrElse("PATH", "")
        .split(File.pathSeparator)
        .filter(_.length > 0)
    }
  }

  def windowsSearchPaths(filesystem: Filesystem) : Iterable[String] = {
    filesystem.programFilesPath.toSeq.flatMap({ (s: String) => Seq(
      // EnterpriseDB, according to http://www.enterprisedb.com/resources-community/pginst-guide
      s"$s\\PostgreSQL\\9.3\\bin",
      s"$s\\PostgreSQL\\9.2\\bin",
      s"$s\\PostgreSQL\\9.1\\bin",
      s"$s\\PostgreSQL\\9.0\\bin"
    )})
  }

  private def findAbsoluteSbinPath(filesystem: Filesystem) : String = {
    def isPostgresHere(path: String) : Boolean = {
      RequiredCommands.forall(c => filesystem.isFileExecutable(new File(path, c).toString))
    }
    val allPaths = filesystem.envPaths ++ windowsSearchPaths(filesystem) ++ UnixStandardSearchPaths
    allPaths
      .find(isPostgresHere(_))
      .getOrElse(throw new Exception(s"Could not find Postgres 9.0-9.3. Please install ${RequiredCommands.mkString(", ")} (which must be executable) in one of: ${allPaths.mkString(", ")}"))
  }

  def apply(basename: String, args: String*) : PostgresCommand = {
    apply(Filesystem, basename, args: _*)
  }

  def apply(filesystem: Filesystem, basename: String, args: String*) : PostgresCommand = {
    val path = new File(findAbsoluteSbinPath(filesystem), basename).toString
    new PostgresCommand(Seq(path) ++ args)
  }
}
