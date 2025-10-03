import OpenMM

let pluginsDirectory = OpenMM_Platform.defaultPluginsDirectory
guard let pluginsDirectory else {
  fatalError("Could not find the OpenMM plugins directory.")
}
print("default plugins directory:", pluginsDirectory)

OpenMM_Platform.loadPlugins(directory: pluginsDirectory)

let platforms = OpenMM_Platform.platforms
print(platforms.count)
for platform in platforms {
  print(platform.name)
}
