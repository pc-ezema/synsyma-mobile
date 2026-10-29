class Env {
  static const apiUrl = String.fromEnvironment('API_URL');
  static const name = String.fromEnvironment('ENV', defaultValue: 'dev');
}