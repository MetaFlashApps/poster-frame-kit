enum ExampleAnalysisState {
  case idle
  case loading(fileName: String)
  case success(fileName: String, selection: ExampleSelection)
  case failure(fileName: String?, message: String)
}
