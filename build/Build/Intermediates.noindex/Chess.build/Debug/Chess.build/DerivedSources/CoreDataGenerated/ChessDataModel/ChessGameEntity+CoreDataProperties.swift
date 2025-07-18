//
//  ChessGameEntity+CoreDataProperties.swift
//  
//
//  Created by Danny Atcheson on 18/07/2025.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension ChessGameEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChessGameEntity> {
        return NSFetchRequest<ChessGameEntity>(entityName: "ChessGameEntity")
    }

    @NSManaged public var blackPlayer: String?
    @NSManaged public var date: String?
    @NSManaged public var dateCreated: Date?
    @NSManaged public var eco: String?
    @NSManaged public var event: String?
    @NSManaged public var id: UUID?
    @NSManaged public var lastModified: Date?
    @NSManaged public var notes: String?
    @NSManaged public var pgnString: String?
    @NSManaged public var result: String?
    @NSManaged public var round: String?
    @NSManaged public var site: String?
    @NSManaged public var title: String?
    @NSManaged public var whitePlayer: String?

}

extension ChessGameEntity : Identifiable {

}
