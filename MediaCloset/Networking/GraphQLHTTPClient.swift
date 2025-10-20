//
//  Networking/GraphQLHTTPClient.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import Foundation

final class GraphQLHTTPClient {
    static let shared = GraphQLHTTPClient()
    private struct Config {
        static var env: [String: String] { ProcessInfo.processInfo.environment }

        static func string(for key: String) -> String? {
            env[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        static var graphqlEndpoint: URL? {
            guard
                let raw = string(for: "GRAPHQL_ENDPOINT"),
                let url = URL(string: raw)
            else {
                #if DEBUG
                print("[GraphQLHTTPClient] Missing or invalid GRAPHQL_ENDPOINT in environment.")
                #endif
                return nil
            }
            return url
        }

        static var hasuraAdminSecret: String? {
            string(for: "HASURA_ADMIN_SECRET").flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    var endpointURL: URL = {
        if let url = Config.graphqlEndpoint {
            return url
        }
        assertionFailure("Missing or invalid GRAPHQL_ENDPOINT")
        return URL(string: "https://example.invalid/graphql")!
    }()

    var extraHeaders: [String:String] = {
        var headers: [String:String] = [
            "Content-Type": "application/json"
        ]
        if let secret = Config.hasuraAdminSecret, !secret.isEmpty {
            headers["x-hasura-admin-secret"] = secret
        } else {
            #if DEBUG
            print("[GraphQLHTTPClient] Warning: HASURA_ADMIN_SECRET not set; proceeding without admin header.")
            #endif
        }
        return headers
    }()

    struct Response { let data: [String: Any]?; let errors: [[String: Any]]? }

    func execute(operationName: String,
                 query: String,
                 variables: [String: Any]? = nil) async throws -> Response {

        var req = URLRequest(url: endpointURL)
        req.httpMethod = "POST"
        for (k,v) in extraHeaders { req.addValue(v, forHTTPHeaderField: k) }

        let body: [String: Any] = [
            "operationName": operationName,
            "query": query,
            "variables": variables ?? [:]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let errors = json?["errors"] as? [[String: Any]]
        if let errors, !errors.isEmpty {
            print("GraphQL errors:", errors)
        }
        return Response(data: json?["data"] as? [String: Any], errors: errors)
    }
}
