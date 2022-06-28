class Layer {
  final String name;

  Map _value;
  Function(Layer, String) _onParamExposure;

  Layer(this.name, [this._value = const {}, this._onParamExposure = noop]) {}

  T? get<T>(String key, [T? defaultValue]) {
    var result = _value[key];

    if (result != null) {
      _onParamExposure(this, key);
    }
    return _value[key] ?? defaultValue;
  }
}

noop(a, b) {}