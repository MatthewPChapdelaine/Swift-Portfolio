#!/usr/bin/env swift

import Foundation
import Accelerate

// MARK: - Matrix Operations

/// High-performance matrix type using Accelerate framework
struct Matrix {
    let rows: Int
    let cols: Int
    private(set) var data: [Double]
    
    init(rows: Int, cols: Int, data: [Double]) {
        precondition(data.count == rows * cols, "Data size must match dimensions")
        self.rows = rows
        self.cols = cols
        self.data = data
    }
    
    init(rows: Int, cols: Int, repeating value: Double = 0.0) {
        self.rows = rows
        self.cols = cols
        self.data = Array(repeating: value, count: rows * cols)
    }
    
    /// Initialize with random values using Xavier initialization
    static func random(rows: Int, cols: Int) -> Matrix {
        let limit = sqrt(6.0 / Double(rows + cols))
        let data = (0..<(rows * cols)).map { _ in
            Double.random(in: -limit...limit)
        }
        return Matrix(rows: rows, cols: cols, data: data)
    }
    
    subscript(row: Int, col: Int) -> Double {
        get { data[row * cols + col] }
        set { data[row * cols + col] = newValue }
    }
    
    /// Matrix multiplication using Accelerate's BLAS
    static func * (lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.cols == rhs.rows, "Matrix dimensions must match")
        
        var result = Matrix(rows: lhs.rows, cols: rhs.cols)
        
        // Use vDSP for high-performance matrix multiplication
        vDSP_mmulD(
            lhs.data, 1,
            rhs.data, 1,
            &result.data, 1,
            vDSP_Length(lhs.rows),
            vDSP_Length(rhs.cols),
            vDSP_Length(lhs.cols)
        )
        
        return result
    }
    
    /// Element-wise addition
    static func + (lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.rows == rhs.rows && lhs.cols == rhs.cols, "Matrix dimensions must match")
        
        var result = Matrix(rows: lhs.rows, cols: lhs.cols)
        vDSP_vaddD(lhs.data, 1, rhs.data, 1, &result.data, 1, vDSP_Length(lhs.data.count))
        return result
    }
    
    /// Element-wise subtraction
    static func - (lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.rows == rhs.rows && lhs.cols == rhs.cols, "Matrix dimensions must match")
        
        var result = Matrix(rows: lhs.rows, cols: lhs.cols)
        vDSP_vsubD(rhs.data, 1, lhs.data, 1, &result.data, 1, vDSP_Length(lhs.data.count))
        return result
    }
    
    /// Element-wise multiplication (Hadamard product)
    func hadamard(_ other: Matrix) -> Matrix {
        precondition(rows == other.rows && cols == other.cols, "Matrix dimensions must match")
        
        var result = Matrix(rows: rows, cols: cols)
        vDSP_vmulD(data, 1, other.data, 1, &result.data, 1, vDSP_Length(data.count))
        return result
    }
    
    /// Scalar multiplication
    static func * (lhs: Matrix, rhs: Double) -> Matrix {
        var result = Matrix(rows: lhs.rows, cols: lhs.cols)
        var scalar = rhs
        vDSP_vsmulD(lhs.data, 1, &scalar, &result.data, 1, vDSP_Length(lhs.data.count))
        return result
    }
    
    /// Transpose
    func transposed() -> Matrix {
        var result = Matrix(rows: cols, cols: rows)
        vDSP_mtransD(data, 1, &result.data, 1, vDSP_Length(cols), vDSP_Length(rows))
        return result
    }
    
    /// Apply function element-wise
    func map(_ transform: (Double) -> Double) -> Matrix {
        return Matrix(rows: rows, cols: cols, data: data.map(transform))
    }
}

// MARK: - Activation Functions

/// Common activation functions and their derivatives
enum Activation {
    /// Sigmoid activation: 1 / (1 + e^(-x))
    static func sigmoid(_ x: Double) -> Double {
        return 1.0 / (1.0 + exp(-x))
    }
    
    static func sigmoidDerivative(_ x: Double) -> Double {
        let s = sigmoid(x)
        return s * (1.0 - s)
    }
    
    /// ReLU activation: max(0, x)
    static func relu(_ x: Double) -> Double {
        return max(0.0, x)
    }
    
    static func reluDerivative(_ x: Double) -> Double {
        return x > 0 ? 1.0 : 0.0
    }
    
    /// Tanh activation
    static func tanh(_ x: Double) -> Double {
        return Darwin.tanh(x)
    }
    
    static func tanhDerivative(_ x: Double) -> Double {
        let t = tanh(x)
        return 1.0 - t * t
    }
}

// MARK: - Loss Functions

/// Common loss functions
enum Loss {
    /// Mean Squared Error
    static func mse(predictions: Matrix, targets: Matrix) -> Double {
        precondition(predictions.rows == targets.rows && predictions.cols == targets.cols)
        
        let diff = predictions - targets
        let squared = diff.hadamard(diff)
        return squared.data.reduce(0, +) / Double(squared.data.count)
    }
    
    static func mseDerivative(predictions: Matrix, targets: Matrix) -> Matrix {
        let diff = predictions - targets
        return diff * (2.0 / Double(predictions.data.count))
    }
    
    /// Binary Cross-Entropy
    static func binaryCrossEntropy(predictions: Matrix, targets: Matrix) -> Double {
        precondition(predictions.rows == targets.rows && predictions.cols == targets.cols)
        
        var sum = 0.0
        for i in 0..<predictions.data.count {
            let p = max(min(predictions.data[i], 0.9999), 0.0001) // Clip for stability
            let t = targets.data[i]
            sum += t * log(p) + (1 - t) * log(1 - p)
        }
        return -sum / Double(predictions.data.count)
    }
}

// MARK: - Neural Network Layer

/// A single layer in a neural network
struct Layer {
    var weights: Matrix
    var biases: Matrix
    let activation: (Double) -> Double
    let activationDerivative: (Double) -> Double
    
    // Cached values for backpropagation
    var lastInput: Matrix?
    var lastZ: Matrix?
    var lastOutput: Matrix?
    
    init(inputSize: Int, outputSize: Int, activation: @escaping (Double) -> Double, activationDerivative: @escaping (Double) -> Double) {
        self.weights = Matrix.random(rows: inputSize, cols: outputSize)
        self.biases = Matrix(rows: 1, cols: outputSize, repeating: 0.0)
        self.activation = activation
        self.activationDerivative = activationDerivative
    }
    
    /// Forward pass through the layer
    mutating func forward(_ input: Matrix) -> Matrix {
        lastInput = input
        
        // Z = X * W + b
        let z = (input * weights) + biases
        lastZ = z
        
        // A = activation(Z)
        let output = z.map(activation)
        lastOutput = output
        
        return output
    }
    
    /// Backward pass through the layer
    mutating func backward(gradient: Matrix, learningRate: Double) -> Matrix {
        guard let input = lastInput, let z = lastZ else {
            fatalError("Must call forward before backward")
        }
        
        // Compute gradient of activation
        let activationGrad = z.map(activationDerivative)
        let delta = gradient.hadamard(activationGrad)
        
        // Compute gradients for weights and biases
        let weightGrad = input.transposed() * delta
        
        // Compute bias gradient (sum along batch dimension)
        var biasGrad = Matrix(rows: 1, cols: biases.cols, repeating: 0.0)
        for col in 0..<delta.cols {
            var sum = 0.0
            for row in 0..<delta.rows {
                sum += delta[row, col]
            }
            biasGrad[0, col] = sum
        }
        
        // Update weights and biases
        weights = weights - (weightGrad * learningRate)
        biases = biases - (biasGrad * learningRate)
        
        // Compute gradient for previous layer
        return delta * weights.transposed()
    }
}

// MARK: - Neural Network

/// Multi-layer neural network with backpropagation
struct NeuralNetwork {
    private var layers: [Layer]
    
    init(layerSizes: [Int]) {
        precondition(layerSizes.count >= 2, "Need at least input and output layers")
        
        layers = []
        for i in 0..<(layerSizes.count - 1) {
            let isLastLayer = i == layerSizes.count - 2
            
            // Use sigmoid for output layer, ReLU for hidden layers
            let (activation, derivative) = isLastLayer
                ? (Activation.sigmoid, Activation.sigmoidDerivative)
                : (Activation.relu, Activation.reluDerivative)
            
            let layer = Layer(
                inputSize: layerSizes[i],
                outputSize: layerSizes[i + 1],
                activation: activation,
                activationDerivative: derivative
            )
            layers.append(layer)
        }
    }
    
    /// Forward pass through the entire network
    mutating func forward(_ input: Matrix) -> Matrix {
        var output = input
        for i in 0..<layers.count {
            output = layers[i].forward(output)
        }
        return output
    }
    
    /// Train the network on a batch of data
    mutating func train(inputs: Matrix, targets: Matrix, learningRate: Double) -> Double {
        // Forward pass
        let predictions = forward(inputs)
        
        // Compute loss
        let loss = Loss.mse(predictions: predictions, targets: targets)
        
        // Backward pass
        var gradient = Loss.mseDerivative(predictions: predictions, targets: targets)
        
        for i in stride(from: layers.count - 1, through: 0, by: -1) {
            gradient = layers[i].backward(gradient: gradient, learningRate: learningRate)
        }
        
        return loss
    }
    
    /// Predict on new data
    mutating func predict(_ input: Matrix) -> Matrix {
        return forward(input)
    }
}

// MARK: - Linear Regression

/// Simple linear regression using gradient descent
struct LinearRegression {
    private var weights: Matrix
    private var bias: Double = 0.0
    
    init(features: Int) {
        self.weights = Matrix.random(rows: features, cols: 1)
    }
    
    /// Predict using current weights
    func predict(_ X: Matrix) -> Matrix {
        let predictions = X * weights
        return predictions.map { $0 + bias }
    }
    
    /// Train using gradient descent
    mutating func train(X: Matrix, y: Matrix, learningRate: Double = 0.01, epochs: Int = 1000) -> [Double] {
        var lossHistory: [Double] = []
        let m = Double(X.rows)
        
        for epoch in 0..<epochs {
            // Forward pass
            let predictions = predict(X)
            
            // Compute loss (MSE)
            let loss = Loss.mse(predictions: predictions, targets: y)
            lossHistory.append(loss)
            
            // Backward pass (compute gradients)
            let error = predictions - y
            let weightGrad = X.transposed() * error
            
            var biasGrad = 0.0
            for row in 0..<error.rows {
                biasGrad += error[row, 0]
            }
            
            // Update parameters
            weights = weights - (weightGrad * (learningRate / m))
            bias -= (biasGrad * learningRate / m)
            
            if epoch % 100 == 0 {
                print("Epoch \(epoch): Loss = \(String(format: "%.6f", loss))")
            }
        }
        
        return lossHistory
    }
}

// MARK: - Logistic Regression

/// Logistic regression for binary classification
struct LogisticRegression {
    private var weights: Matrix
    private var bias: Double = 0.0
    
    init(features: Int) {
        self.weights = Matrix.random(rows: features, cols: 1)
    }
    
    /// Predict probabilities
    func predict(_ X: Matrix) -> Matrix {
        let z = (X * weights).map { $0 + bias }
        return z.map(Activation.sigmoid)
    }
    
    /// Predict classes (0 or 1)
    func predictClass(_ X: Matrix) -> [Int] {
        let probabilities = predict(X)
        return probabilities.data.map { $0 >= 0.5 ? 1 : 0 }
    }
    
    /// Train using gradient descent
    mutating func train(X: Matrix, y: Matrix, learningRate: Double = 0.01, epochs: Int = 1000) -> [Double] {
        var lossHistory: [Double] = []
        let m = Double(X.rows)
        
        for epoch in 0..<epochs {
            // Forward pass
            let predictions = predict(X)
            
            // Compute loss (binary cross-entropy)
            let loss = Loss.binaryCrossEntropy(predictions: predictions, targets: y)
            lossHistory.append(loss)
            
            // Backward pass
            let error = predictions - y
            let weightGrad = X.transposed() * error
            
            var biasGrad = 0.0
            for row in 0..<error.rows {
                biasGrad += error[row, 0]
            }
            
            // Update parameters
            weights = weights - (weightGrad * (learningRate / m))
            bias -= (biasGrad * learningRate / m)
            
            if epoch % 100 == 0 {
                print("Epoch \(epoch): Loss = \(String(format: "%.6f", loss))")
            }
        }
        
        return lossHistory
    }
    
    /// Calculate accuracy
    func accuracy(X: Matrix, y: Matrix) -> Double {
        let predictions = predictClass(X)
        var correct = 0
        for i in 0..<predictions.count {
            if predictions[i] == Int(y.data[i]) {
                correct += 1
            }
        }
        return Double(correct) / Double(predictions.count)
    }
}

// MARK: - Main Demo

@main
struct MachineLearning {
    static func main() {
        print("=== Machine Learning from Scratch ===\n")
        
        // Demo 1: Linear Regression
        print("1. Linear Regression Demo")
        print("   Fitting y = 2x + 1 with noise\n")
        
        // Generate synthetic data: y = 2x + 1 + noise
        let numSamples = 100
        var X_data: [Double] = []
        var y_data: [Double] = []
        
        for i in 0..<numSamples {
            let x = Double(i) / 10.0
            let y = 2.0 * x + 1.0 + Double.random(in: -0.5...0.5)
            X_data.append(x)
            y_data.append(y)
        }
        
        var X = Matrix(rows: numSamples, cols: 1, data: X_data)
        var y = Matrix(rows: numSamples, cols: 1, data: y_data)
        
        var linearModel = LinearRegression(features: 1)
        let _ = linearModel.train(X: X, y: y, learningRate: 0.01, epochs: 500)
        
        let testX = Matrix(rows: 1, cols: 1, data: [5.0])
        let prediction = linearModel.predict(testX)
        print("   Prediction for x=5.0: \(String(format: "%.2f", prediction[0, 0]))")
        print("   Expected: ~11.0\n")
        
        // Demo 2: Logistic Regression
        print("2. Logistic Regression Demo")
        print("   Binary classification\n")
        
        // Generate synthetic binary classification data
        X_data = []
        y_data = []
        
        for _ in 0..<50 {
            let x = Double.random(in: 0...5)
            X_data.append(x)
            y_data.append(0.0)
        }
        
        for _ in 0..<50 {
            let x = Double.random(in: 5...10)
            X_data.append(x)
            y_data.append(1.0)
        }
        
        X = Matrix(rows: 100, cols: 1, data: X_data)
        y = Matrix(rows: 100, cols: 1, data: y_data)
        
        var logisticModel = LogisticRegression(features: 1)
        let _ = logisticModel.train(X: X, y: y, learningRate: 0.1, epochs: 500)
        
        let accuracy = logisticModel.accuracy(X: X, y: y)
        print("   Training Accuracy: \(String(format: "%.2f%%", accuracy * 100))\n")
        
        // Demo 3: Neural Network
        print("3. Neural Network Demo")
        print("   XOR problem (non-linearly separable)\n")
        
        // XOR dataset
        let xorX = Matrix(rows: 4, cols: 2, data: [
            0, 0,
            0, 1,
            1, 0,
            1, 1
        ])
        
        let xorY = Matrix(rows: 4, cols: 1, data: [
            0, 1, 1, 0
        ])
        
        var nn = NeuralNetwork(layerSizes: [2, 4, 1])
        
        print("   Training neural network...")
        for epoch in 0..<2000 {
            let loss = nn.train(inputs: xorX, targets: xorY, learningRate: 0.1)
            
            if epoch % 500 == 0 {
                print("   Epoch \(epoch): Loss = \(String(format: "%.6f", loss))")
            }
        }
        
        print("\n   Testing XOR predictions:")
        let predictions = nn.predict(xorX)
        for i in 0..<4 {
            let input = (Int(xorX[i, 0]), Int(xorX[i, 1]))
            let predicted = predictions[i, 0]
            let actual = Int(xorY[i, 0])
            let predictedClass = predicted >= 0.5 ? 1 : 0
            print("   \(input.0) XOR \(input.1) = \(actual), Predicted: \(String(format: "%.4f", predicted)) (\(predictedClass))")
        }
        
        print("\n=== Demo Completed ===")
        print("\nKey Features Demonstrated:")
        print("  ✓ Matrix operations using Accelerate framework")
        print("  ✓ Linear regression with gradient descent")
        print("  ✓ Logistic regression for binary classification")
        print("  ✓ Neural network with backpropagation")
        print("  ✓ Multiple activation functions (Sigmoid, ReLU, Tanh)")
        print("  ✓ Loss functions (MSE, Binary Cross-Entropy)")
        print("  ✓ Value types for immutability and performance")
    }
}
