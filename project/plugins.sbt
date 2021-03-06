logLevel := Level.Warn

resolvers += "Typesafe repository" at "http://repo.typesafe.com/typesafe/releases/"

resolvers += "Templemore Repository" at "http://templemore.co.uk/repo"

resolvers += Resolver.url("community", url("http://scalasbt.artifactoryonline.com/scalasbt/sbt-plugin-releases/"))(Resolver.ivyStylePatterns)

addSbtPlugin("templemore" % "sbt-cucumber-plugin" % "0.8.0")

addSbtPlugin("com.typesafe.play" % "sbt-plugin" % "2.2.2-RC2")
