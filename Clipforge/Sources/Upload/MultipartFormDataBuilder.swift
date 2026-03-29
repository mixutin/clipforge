import Foundation

struct MultipartFormDataBuilder {
    let boundary: String

    func build(fileField: String, filename: String, mimeType: String, data: Data) -> Data {
        var body = Data()

        append("--\(boundary)\r\n", to: &body)
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n", to: &body)
        append("Content-Type: \(mimeType)\r\n\r\n", to: &body)
        body.append(data)
        append("\r\n--\(boundary)--\r\n", to: &body)

        return body
    }

    private func append(_ string: String, to data: inout Data) {
        data.append(Data(string.utf8))
    }
}
