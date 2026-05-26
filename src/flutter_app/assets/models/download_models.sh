#!/bin/bash
# Download TFLite model files for PoseCraft on-device ML inference.
# Run this script from within assets/models/.
#
# Models:
#   1. scene_classifier.tflite    — MobileNetV3-Small scene classifier (20 classes)
#   2. depth_estimation.tflite    — MiDaS v2.1 Small depth estimation (256×256)
#   3. lighting_analyzer.tflite   — Custom lighting CNN (placeholder)
#
# Sources:
#   - Scene classifier: train on Places365 subset (20 classes) → convert to TFLite
#   - Depth: MiDaS v2.1 from PyTorch Hub → ONNX → TFLite
#   - Lighting: custom model (train on photo lighting dataset)
#
# For development, run: ./download_models.sh

set -e
cd "$(dirname "$0")"

echo "PoseCraft Model Download"
echo "========================"
echo ""

# --- Scene Classifier ---
if [ -f "scene_classifier.tflite" ]; then
    echo "[OK] scene_classifier.tflite already exists"
else
    echo "[MISSING] scene_classifier.tflite"
    echo "  To generate:"
    echo "  1. Train MobileNetV3-Small on a 20-class subset of Places365"
    echo "  2. Export to frozen graph (.pb)"
    echo "  3. Convert: tflite_convert --saved_model_dir=./export --output_file=scene_classifier.tflite"
    echo "  4. Place in assets/models/"
    echo ""
fi

# --- Depth Estimation ---
if [ -f "depth_estimation.tflite" ]; then
    echo "[OK] depth_estimation.tflite already exists"
else
    echo "[MISSING] depth_estimation.tflite"
    echo "  To generate from PyTorch Hub:"
    echo "  1. pip install torch onnx onnx-tf"
    echo "  2. python -c \""
    echo "    import torch"
    echo "    model = torch.hub.load('intel-isl/MiDaS', 'MiDaS_small')"
    echo "    model.eval()"
    echo "    dummy = torch.randn(1, 3, 256, 256)"
    echo "    torch.onnx.export(model, dummy, 'midas.onnx', opset_version=11)"
    echo "  \""
    echo "  3. onnx-tf convert -i midas.onnx -o midas_tf/"
    echo "  4. tflite_convert --saved_model_dir=midas_tf/ --output_file=depth_estimation.tflite"
    echo "  5. Place in assets/models/"
    echo ""
fi

# --- Lighting Analyzer ---
if [ -f "lighting_analyzer.tflite" ]; then
    echo "[OK] lighting_analyzer.tflite already exists"
else
    echo "[MISSING] lighting_analyzer.tflite — placeholder model, not yet implemented"
    echo ""
fi

echo "========================"
echo "Models ready for development."
echo "If models are missing, the app uses rule-based fallback automatically."
