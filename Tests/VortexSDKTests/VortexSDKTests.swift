import XCTest
@testable import VortexSDK

final class VortexSDKTests: XCTestCase {
    func testPlaceholder() throws {
        // Placeholder test
        XCTAssertTrue(true)
    }
    
    func testLegacyWidgetConfigurationDecoding() throws {
        // Test that legacy widget configuration with WebPageData valueType can be decoded
        let legacyConfigJSON = """
        {
            "id": "test-id",
            "name": "Test Widget",
            "slug": "test-slug",
            "configuration": {
                "meta": {
                    "configuration": {
                        "version": "0.0.1",
                        "componentType": "invite_people"
                    }
                },
                "props": {
                    "vortex.components.form": {
                        "value": {
                            "root": {
                                "id": "root-id",
                                "type": "root",
                                "subtype": "vrtx-root",
                                "tagName": "vrtx-root",
                                "style": {"width": "300px"},
                                "attributes": {},
                                "settings": {},
                                "children": [
                                    {
                                        "id": "row-id",
                                        "type": "row",
                                        "subtype": "vrtx-row",
                                        "tagName": "vrtx-row",
                                        "attributes": {},
                                        "settings": {},
                                        "children": [
                                            {
                                                "id": "col-id",
                                                "type": "column",
                                                "subtype": "vrtx-column",
                                                "tagName": "vrtx-column",
                                                "attributes": {},
                                                "settings": {"size": {"xs": 12}},
                                                "children": [
                                                    {
                                                        "id": "label-id",
                                                        "type": "block",
                                                        "subtype": "vrtx-form-label",
                                                        "tagName": "label",
                                                        "style": {"fontWeight": "700"},
                                                        "attributes": {
                                                            "for": ["id1", "id2"],
                                                            "name": "formlabel"
                                                        },
                                                        "settings": {},
                                                        "textContent": "Test Label",
                                                        "children": [],
                                                        "schemaVersion": 1
                                                    }
                                                ],
                                                "schemaVersion": 1
                                            }
                                        ],
                                        "schemaVersion": 1
                                    }
                                ],
                                "schemaVersion": 1
                            }
                        },
                        "valueType": "WebPageData"
                    }
                }
            }
        }
        """
        
        let data = legacyConfigJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let config = try decoder.decode(WidgetConfiguration.self, from: data)
        
        XCTAssertEqual(config.id, "test-id")
        XCTAssertEqual(config.name, "Test Widget")
        
        // Verify form structure is accessible
        let formProp = config.configuration.props["vortex.components.form"]
        XCTAssertNotNil(formProp)
        
        if case .pageData(let pageData) = formProp?.value {
            XCTAssertEqual(pageData.root.id, "root-id")
            XCTAssertEqual(pageData.root.type, "root")
            XCTAssertEqual(pageData.root.children?.count, 1)
            
            // Verify nested structure
            let row = pageData.root.children?.first
            XCTAssertEqual(row?.type, "row")
            
            let column = row?.children?.first
            XCTAssertEqual(column?.type, "column")
            
            let label = column?.children?.first
            XCTAssertEqual(label?.type, "block")
            XCTAssertEqual(label?.subtype, "vrtx-form-label")
            XCTAssertEqual(label?.textContent, "Test Label")
            
            // Verify array attribute decoding
            if let forAttr = label?.attributes?["for"], case .stringArray(let ids) = forAttr {
                XCTAssertEqual(ids, ["id1", "id2"])
            } else {
                XCTFail("Expected 'for' attribute to be a string array")
            }
        } else {
            XCTFail("Expected pageData value type")
        }
    }
}
