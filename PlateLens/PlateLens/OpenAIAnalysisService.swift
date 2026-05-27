import Foundation
import UIKit

struct OpenAIAnalysisService {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    func analyze(image: UIImage, apiKey: String, model: String) async throws -> MealEstimate {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            throw MealAnalysisError.missingAPIKey
        }

        guard let imageData = image.resizedForAnalysis().jpegData(compressionQuality: 0.82) else {
            throw MealAnalysisError.invalidImage
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ResponsesRequest(
            model: trimmedModel.isEmpty ? "gpt-4.1-mini" : trimmedModel,
            input: [
                .init(
                    role: "user",
                    content: [
                        .inputText(Self.prompt),
                        .inputImage("data:image/jpeg;base64,\(imageData.base64EncodedString())")
                    ]
                )
            ],
            text: .init(format: .jsonObject)
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw MealAnalysisError.serverMessage(apiError.error.message)
            }
            throw MealAnalysisError.serverMessage("Analysis failed with status \(http.statusCode).")
        }

        let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        let text = (decoded.outputText ?? decoded.output
            .compactMap(\.content)
            .flatMap { $0 }
            .compactMap(\.text)
            .joined())
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw MealAnalysisError.emptyResult
        }

        guard let jsonData = Self.jsonData(from: text) else {
            throw MealAnalysisError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(MealEstimate.self, from: jsonData)
        } catch {
            throw MealAnalysisError.invalidResponse
        }
    }

    private static func jsonData(from text: String) -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            return nil
        }

        let jsonSlice = String(trimmed[start...end])
        guard let data = jsonSlice.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return nil
        }

        return data
    }

    private static let prompt = """
    You are a careful nutrition estimator for a private meal diary app.

    Analyze the food in the image and estimate nutrition. Return only valid JSON, no markdown.
    Use grams where possible. If the portion is uncertain, make a reasonable estimate and lower confidence.
    If the image is not food, return a low confidence estimate with title "Not a meal".

    Required JSON shape:
    {
      "title": "short meal name",
      "calories": 520,
      "protein": 31.0,
      "carbs": 48.0,
      "fat": 19.0,
      "confidence": 0.72,
      "portionDescription": "estimated portion size",
      "assumptions": ["brief assumption"],
      "ingredients": [
        {
          "name": "ingredient",
          "amount": "120 g",
          "calories": 120,
          "protein": 5.0,
          "carbs": 10.0,
          "fat": 3.0
        }
      ]
    }
    """
}

private struct ResponsesRequest: Encodable {
    var model: String
    var input: [InputMessage]
    var text: TextConfig

    struct InputMessage: Encodable {
        var role: String
        var content: [InputContent]
    }

    struct TextConfig: Encodable {
        var format: ResponseFormat
    }

    struct ResponseFormat: Encodable {
        var type: String

        static let jsonObject = ResponseFormat(type: "json_object")
    }
}

private enum InputContent: Encodable {
    case inputText(String)
    case inputImage(String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .inputText(let text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .inputImage(let imageURL):
            try container.encode("input_image", forKey: .type)
            try container.encode(imageURL, forKey: .imageURL)
        }
    }
}

private struct ResponsesResponse: Decodable {
    var outputText: String?
    var output: [OutputItem]

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }

    struct OutputItem: Decodable {
        var content: [OutputContent]?
    }

    struct OutputContent: Decodable {
        var text: String?
    }
}

private struct OpenAIErrorResponse: Decodable {
    var error: APIError

    struct APIError: Decodable {
        var message: String
    }
}

private extension UIImage {
    func resizedForAnalysis(maxDimension: CGFloat = 1280) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else {
            return self
        }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
