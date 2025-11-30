//
//  Networking/GraphQLHTTPClient.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
//  DEPRECATED: This file is no longer used.
//  All GraphQL operations now go through MediaClosetAPIClient
//  which proxies requests through the Go API backend.
//
//  Direct Hasura access has been removed for security.
//
//  Operations that need to be re-implemented in the Go API:
//  - Delete mutations (deleteVHS, deleteRecord)
//  - Update mutations (updateVHS, updateRecord)
//  - Detail queries (vhsDetail, recordDetail)

import Foundation

@available(*, deprecated, message: "Use MediaClosetAPIClient instead. Direct Hasura access has been removed.")
enum GraphQLError: Error {
    case deprecated
}

@available(*, deprecated, message: "Use MediaClosetAPIClient instead. Direct Hasura access has been removed.")
final class GraphQLHTTPClient {
    static let shared = GraphQLHTTPClient()

    var endpointURL: URL? {
        return nil
    }

    var extraHeaders: [String:String] {
        return [:]
    }

    struct Response { let data: [String: Any]?; let errors: [[String: Any]]? }

    func execute(operationName: String,
                 query: String,
                 variables: [String: Any]? = nil) async throws -> Response {
        throw GraphQLError.deprecated
    }
}
