package runtime

import (
	"fmt"
	"os"
	"reflect"
	"strconv"
	"strings"
)

const fileEnvPrefix = "READFILE:"

func updateConfigFromEnv(cfg, networkData any, prefix string) error {
	if prefix == "" {
		return nil
	}

	cfgVal := reflect.ValueOf(cfg)
	networkVal := reflect.ValueOf(networkData)

	for _, env := range os.Environ() {
		if !strings.HasPrefix(env, prefix) {
			continue
		}

		keyValue := strings.SplitN(env, "=", 2)
		if len(keyValue) != 2 {
			continue
		}

		key := strings.TrimPrefix(keyValue[0], prefix)
		value := keyValue[1]
		if strings.HasSuffix(key, "_FILE") {
			key = strings.TrimSuffix(key, "_FILE")
			value = fileEnvPrefix + value
		}

		key = strings.ToLower(key)
		lookupKey := key
		if !strings.ContainsRune(key, '.') {
			key = strings.ReplaceAll(key, "__", ".")
		}

		path := strings.Split(key, ".")
		field, ok := reflectGetFromMainOrNetwork(cfgVal, networkVal, path)
		if !ok && !strings.ContainsRune(lookupKey, '.') {
			field, ok = reflectGetFromMainOrNetworkTokens(cfgVal, networkVal, strings.Split(lookupKey, "_"))
		}
		if !ok {
			return fmt.Errorf("%s not found", formatKey(path))
		}

		if strings.HasPrefix(value, fileEnvPrefix) {
			filePath := strings.TrimPrefix(value, fileEnvPrefix)
			fileData, err := os.ReadFile(filePath)
			if err != nil {
				return fmt.Errorf("failed to read file %s for %s: %w", filePath, formatKey(path), err)
			}
			value = strings.TrimSpace(string(fileData))
		}

		if err := setReflectedValue(field, path, value); err != nil {
			return err
		}
	}

	return nil
}

type reflectedField struct {
	value         reflect.Value
	valueKind     reflect.Kind
	remainingPath []string
}

func formatKey(path []string) string {
	return strings.Join(path, "->")
}

func reflectGetFromMainOrNetwork(main, network reflect.Value, path []string) (*reflectedField, bool) {
	if len(path) > 0 && path[0] == "network" {
		return reflectGetYAML(network, path[1:])
	}
	return reflectGetYAML(main, path)
}

func reflectGetFromMainOrNetworkTokens(main, network reflect.Value, tokens []string) (*reflectedField, bool) {
	if len(tokens) > 0 && normalizeKey(tokens[0]) == "network" {
		return reflectGetYAMLTokens(network, tokens[1:])
	}
	return reflectGetYAMLTokens(main, tokens)
}

func reflectGetYAML(value reflect.Value, path []string) (*reflectedField, bool) {
	if len(path) == 0 {
		return &reflectedField{value: value, valueKind: value.Kind()}, true
	}
	if value.Kind() == reflect.Ptr {
		value = value.Elem()
	}

	switch value.Kind() {
	case reflect.Map:
		return &reflectedField{
			value:         value,
			valueKind:     value.Type().Elem().Kind(),
			remainingPath: path,
		}, true
	case reflect.Struct:
		fields := reflect.VisibleFields(value.Type())
		for _, field := range fields {
			if yamlFieldName(field) != path[0] {
				continue
			}
			return reflectGetYAML(value.FieldByIndex(field.Index), path[1:])
		}
	}

	return nil, false
}

func reflectGetYAMLTokens(value reflect.Value, tokens []string) (*reflectedField, bool) {
	if len(tokens) == 0 {
		return &reflectedField{value: value, valueKind: value.Kind()}, true
	}
	if value.Kind() == reflect.Ptr {
		value = value.Elem()
	}

	switch value.Kind() {
	case reflect.Map:
		return &reflectedField{
			value:         value,
			valueKind:     value.Type().Elem().Kind(),
			remainingPath: []string{strings.Join(tokens, "_")},
		}, true
	case reflect.Struct:
		fields := reflect.VisibleFields(value.Type())
		for _, field := range fields {
			name := yamlFieldName(field)
			if name == "" {
				continue
			}
			normalizedFieldName := normalizeKey(name)
			for i := len(tokens); i >= 1; i-- {
				if normalizeKey(strings.Join(tokens[:i], "_")) != normalizedFieldName {
					continue
				}
				return reflectGetYAMLTokens(value.FieldByIndex(field.Index), tokens[i:])
			}
		}
	}

	return nil, false
}

func yamlFieldName(field reflect.StructField) string {
	parts := strings.SplitN(field.Tag.Get("yaml"), ",", 2)
	switch name := parts[0]; {
	case name == "-" && len(parts) == 1:
		return ""
	case name == "":
		return strings.ToLower(field.Name)
	default:
		return name
	}
}

func normalizeKey(value string) string {
	return strings.ReplaceAll(strings.ToLower(value), "_", "")
}

func setReflectedValue(field *reflectedField, path []string, raw string) error {
	parsed, err := parseValue(field.valueKind, raw, path)
	if err != nil {
		return err
	}

	value := field.value
	if value.Kind() == reflect.Ptr {
		if value.IsNil() {
			value.Set(reflect.New(value.Type().Elem()))
		}
		value = value.Elem()
	}

	if value.Kind() == reflect.Map {
		if value.Type().Key().Kind() != reflect.String {
			return fmt.Errorf("unsupported map key type %s in %s", value.Type().Key().Kind(), formatKey(path))
		}
		key := strings.Join(field.remainingPath, ".")
		value.SetMapIndex(reflect.ValueOf(key), reflect.ValueOf(parsed))
		return nil
	}

	value.Set(reflect.ValueOf(parsed))
	return nil
}

func parseValue(kind reflect.Kind, raw string, path []string) (any, error) {
	switch kind {
	case reflect.String:
		return raw, nil
	case reflect.Bool:
		parsed, err := strconv.ParseBool(raw)
		if err != nil {
			return nil, fmt.Errorf("invalid value for %s: %w", formatKey(path), err)
		}
		return parsed, nil
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid value for %s: %w", formatKey(path), err)
		}
		switch kind {
		case reflect.Int8:
			return int8(parsed), nil
		case reflect.Int16:
			return int16(parsed), nil
		case reflect.Int32:
			return int32(parsed), nil
		case reflect.Int64:
			return parsed, nil
		default:
			return int(parsed), nil
		}
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		parsed, err := strconv.ParseUint(raw, 10, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid value for %s: %w", formatKey(path), err)
		}
		switch kind {
		case reflect.Uint8:
			return uint8(parsed), nil
		case reflect.Uint16:
			return uint16(parsed), nil
		case reflect.Uint32:
			return uint32(parsed), nil
		case reflect.Uint64:
			return parsed, nil
		default:
			return uint(parsed), nil
		}
	case reflect.Float32, reflect.Float64:
		parsed, err := strconv.ParseFloat(raw, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid value for %s: %w", formatKey(path), err)
		}
		if kind == reflect.Float32 {
			return float32(parsed), nil
		}
		return parsed, nil
	default:
		return nil, fmt.Errorf("unsupported type %s in %s", kind, formatKey(path))
	}
}
