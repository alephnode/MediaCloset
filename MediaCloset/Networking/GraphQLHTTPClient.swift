//
//  Networking/GraphQLHTTPClient.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
import Foundation

final class GraphQLHTTPClient {
    static let shared = GraphQLHTTPClient()
    private let secretsManager = SecretsManager.shared

    var endpointURL: URL {
        guard let url = secretsManager.graphqlEndpoint else {
            #if DEBUG
            print("[GraphQLHTTPClient] ERROR: No GraphQL endpoint available. Secrets status:")
            let status = secretsManager.secretsStatus
            for (key, value) in status {
                print("  \(key): \(value)")
            }
            assertionFailure("GRAPHQL_ENDPOINT must be configured. Please set up xcconfig files properly.")
            #endif
            // This will crash in debug, which is intentional to catch configuration issues
            fatalError("GRAPHQL_ENDPOINT not configured")
        }
        return url
    }

    var extraHeaders: [String:String] {
        var headers: [String:String] = [
            "Content-Type": "application/json"
        ]
        if let secret = secretsManager.hasuraAdminSecret, !secret.isEmpty {
            headers["x-hasura-admin-secret"] = secret
        } else {
            #if DEBUG
            print("[GraphQLHTTPClient] Warning: HASURA_ADMIN_SECRET not set; proceeding without admin header.")
            #endif
            // For the demo endpoint, we can proceed without the admin secret
            // as it's a public demo instance
        }
        return headers
    }

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
