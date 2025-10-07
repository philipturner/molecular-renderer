// CPU initializes data to zero on startup
//   (1 upload buffer)
// used in every GPU command
//   (1 native buffer)
// GPU data downloaded to CPU
//   (3 download buffers)
//
// This could be used to easily gather diagnostic data while taking the first
// steps to test & debug BVH building.
