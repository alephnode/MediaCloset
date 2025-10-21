//
//  MediaClosetTests.swift
//  MediaClosetTests
//
//  Created by Stephen Ward on 10/11/25.
//

import XCTest

final class MediaClosetTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
    
    func testOMDBService() async throws {
        // Test OMDB service with a well-known movie
        let movieData = await OMDBService.fetchMovieData(title: "The Matrix", year: 1999)
        
        // Verify we got data back
        XCTAssertNotNil(movieData, "OMDB service should return movie data")
        
        if let data = movieData {
            // Verify key fields are present
            XCTAssertEqual(data["Title"] as? String, "The Matrix", "Title should match")
            XCTAssertEqual(data["Year"] as? String, "1999", "Year should match")
            XCTAssertNotNil(data["Director"], "Director should be present")
            XCTAssertNotNil(data["Poster"], "Poster URL should be present")
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
