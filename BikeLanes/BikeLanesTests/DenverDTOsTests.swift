// BikeLanesTests/DenverDTOsTests.swift
import XCTest
@testable import BikeLanes

final class DenverDTOsTests: XCTestCase {
    func testMenuDecodes() throws {
        let json = """
        [{"menuType":"Report an Issue","title":"Illegal Parking","caseType":"REQ_ILLEGALPARKING",
          "active":true,"sfIssueTemplateId":"a3Gi000000375ai","configuration":"{}",
          "menuQuestions":null,"id":10}]
        """.data(using: .utf8)!
        let menus = try JSONDecoder().decode([DenverMenu].self, from: json)
        XCTAssertEqual(menus.first?.id, 10)
        XCTAssertEqual(menus.first?.caseType, "REQ_ILLEGALPARKING")
        XCTAssertEqual(menus.first?.sfIssueTemplateId, "a3Gi000000375ai")
    }

    func testMenuQuestionDecodes() throws {
        let json = """
        [{"menuId":10,"question":"Plate Number","questionType":"textInput","active":true,
          "required":true,"order":2,"options":"{\\"maxLength\\":10}",
          "sfAnswerField":"Issue_Question_3__c","group":"3","menu":null,"id":22}]
        """.data(using: .utf8)!
        let qs = try JSONDecoder().decode([DenverMenuQuestion].self, from: json)
        XCTAssertEqual(qs.first?.id, 22)
        XCTAssertEqual(qs.first?.sfAnswerField, "Issue_Question_3__c")
    }

    func testAttachmentResponseDecodes() throws {
        let json = """
        {"caseHistoryId":0,"caseNumber":null,"mimeType":"image/heic",
         "pathToFiles":"2026/4/20/x","created":"2026-04-21T02:50:37.679Z",
         "id":"ec3e203a-149e-4fe5-9e2e-528b227c5f2a"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let resp = try decoder.decode(AttachmentResponse.self, from: json)
        XCTAssertEqual(resp.id, UUID(uuidString: "EC3E203A-149E-4FE5-9E2E-528B227C5F2A"))
        XCTAssertEqual(resp.mimeType, "image/heic")
    }

    func testCreateCaseResponseDecodes() throws {
        let json = """
        {"inputRecordId":266859,"attachmentId":"ec3e203a-149e-4fe5-9e2e-528b227c5f2a",
         "menuId":10,"title":"Illegal Parking","email":"","b2CId":"",
         "anonymousId":"00000000-0000-0000-0000-000000000000",
         "created":"2026-04-21T02:52:30Z","closed":null,
         "internalCaseStatus":"queuedForCRM","caseStatus":"New",
         "caseId":null,"caseNumber":null,"resolutionNotes":null,
         "sentStatus":"notSent","sfError":null,"attempts":0,
         "inputRecord":{"userInput":"{}","salesForceInput":null,
                        "created":"2026-04-21T02:52:30Z","caseHistory":null,"id":266859},
         "id":266869}
        """.data(using: .utf8)!
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let r = try decoder.decode(CreateCaseResponse.self, from: json)
        XCTAssertEqual(r.id, 266869)
        XCTAssertEqual(r.internalCaseStatus, "queuedForCRM")
    }
}
