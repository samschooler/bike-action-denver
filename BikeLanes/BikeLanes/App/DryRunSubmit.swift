import Foundation

/// A `CaseSubmitting` that short-circuits without hitting Denver. Activated
/// by the `BIKE_LANES_DRY_RUN=1` environment variable in `BikeLanesApp.init`.
///
/// Used when running the app in a simulator for development so we don't
/// file real cases with Denver 311.
struct DryRunSubmit: CaseSubmitting, MenuProviding, @unchecked Sendable {
    func fetchMenus() async throws -> [DenverMenu] {
        let json = """
        [{"menuType":"Report an Issue","title":"Illegal Parking",
          "caseType":"REQ_ILLEGALPARKING","active":true,
          "sfIssueTemplateId":"a3Gi000000375ai","configuration":"{}",
          "menuQuestions":null,"id":10}]
        """
        return try JSONDecoder().decode([DenverMenu].self, from: Data(json.utf8))
    }

    func fetchMenuQuestions(menuId: Int) async throws -> [DenverMenuQuestion] {
        let json = """
        [{"menuId":10,"question":"Is the vehicle blocking a driveway?","questionType":"radioGroup","active":true,"required":true,"order":0,"options":"{}","sfAnswerField":"Issue_Question_1__c","group":"1","menu":null,"id":20},
         {"menuId":10,"question":"How long has vehicle been parked?","questionType":"textInput","active":true,"required":false,"order":1,"options":"{}","sfAnswerField":"Issue_Question_2__c","group":"2","menu":null,"id":21},
         {"menuId":10,"question":"Plate Number","questionType":"textInput","active":true,"required":true,"order":2,"options":"{}","sfAnswerField":"Issue_Question_3__c","group":"3","menu":null,"id":22},
         {"menuId":10,"question":"Plate State","questionType":"textInput","active":true,"required":true,"order":3,"options":"{}","sfAnswerField":"Issue_Question_4__c","group":"3","menu":null,"id":46},
         {"menuId":10,"question":"Color, make & style of vehicle","questionType":"textInput","active":true,"required":true,"order":4,"options":"{}","sfAnswerField":"Issue_Question_5__c","group":"4","menu":null,"id":47},
         {"menuId":10,"question":"Type of vehicle","questionType":"radioGroup","active":true,"required":true,"order":5,"options":"{}","sfAnswerField":"Issue_Question_6__c","group":"4","menu":null,"id":48},
         {"menuId":10,"question":"Location of vehicle","questionType":"radioGroup","active":true,"required":true,"order":6,"options":"{}","sfAnswerField":"Issue_Question_7__c","group":"5","menu":null,"id":49}]
        """
        return try JSONDecoder().decode([DenverMenuQuestion].self, from: Data(json.utf8))
    }

    func uploadAttachment(id: UUID, filename: String, mimeType: String, data: Data) async throws -> AttachmentResponse {
        try await Task.sleep(nanoseconds: 300_000_000)
        let json = """
        {"caseHistoryId":0,"caseNumber":null,"mimeType":"\(mimeType)",
         "pathToFiles":"dry-run/\(id.uuidString.lowercased())",
         "created":"2026-04-21T00:00:00Z",
         "id":"\(id.uuidString.lowercased())"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AttachmentResponse.self, from: Data(json.utf8))
    }

    func createCase(_ request: CreateCaseRequest) async throws -> CreateCaseResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        let fakeId = Int.random(in: 900_000...999_999)
        let json = """
        {"inputRecordId":\(fakeId),
         "attachmentId":"\(request.attachmentId?.uuidString.lowercased() ?? "00000000-0000-0000-0000-000000000000")",
         "menuId":10,"title":"Illegal Parking","email":"","b2CId":"",
         "anonymousId":"00000000-0000-0000-0000-000000000000",
         "created":"2026-04-21T00:00:00Z","closed":null,
         "internalCaseStatus":"dryRun","caseStatus":"DryRun",
         "caseId":null,"caseNumber":null,"resolutionNotes":null,
         "sentStatus":"notSent","sfError":null,"attempts":0,
         "id":\(fakeId)}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CreateCaseResponse.self, from: Data(json.utf8))
    }
}
