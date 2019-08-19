//
//  CoreData.swift
//  testNews
//
//  Created by Ivan Dyachenko on 15/08/2019.
//  Copyright © 2019 Ivan Dyachenko. All rights reserved.
//

import Foundation
import CoreData

class CoreDataManager: NSObject {
    
    static let shared = CoreDataManager()
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let error = error as NSError?
                fatalError("Unresolved error \(error), \(error?.userInfo)")
            }
        }
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        
        let container = NSPersistentContainer(name: "Entity")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    func getBackgroundContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = persistentContainer.viewContext
        return context
    }
    
    func someEntityExists(title: String) -> Bool {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "News")
        fetchRequest.predicate = NSPredicate(format: "title=%@", title)
        
        var results: [NSManagedObject] = []
        
        do {
            results = try self.persistentContainer.viewContext.fetch(fetchRequest)
        }
        catch {
            print("error executing fetch request: \(error)")
        }
        return results.count > 0
    }
    
    func deleteEntities(entity: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "News")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            let obj = try persistentContainer.viewContext.fetch(fetchRequest)
            let objToDelete = obj as! [NSManagedObject]
            for i in objToDelete {
                persistentContainer.viewContext.delete(i)
                print("Object deleted")
                do {
                    try persistentContainer.viewContext.save()
                    print("saved after delete")
                } catch {
                    print("ERROR delete intities")
                }
            }
        } catch let error as NSError {
            print("ERROR: \(error.localizedDescription)")
        }
    }
    
    func loadImageDataToDB(title: String, imageData: Data?) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "News")
        fetchRequest.predicate = NSPredicate(format: "title=%@", title)
        
        do {
            let results = try self.persistentContainer.viewContext.fetch(fetchRequest) as? [News]
            if results?.count != 0 {
                    results?[0].image = imageData
            }
        } catch {
            print("Failed loading image to DB")
        }
    }
    
    func loadImageFromDB(title: String) -> News? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "News")
        fetchRequest.predicate = NSPredicate(format: "title=%@", title)
        var entity: News?
        do {
            let results = try self.persistentContainer.viewContext.fetch(fetchRequest) as? [News]
            if results?.count != 0 {
                entity = results?[0]
                print("LOADED FROM DB")
            }
        } catch let error {
            print("ERROR FOR FETCHING IMAGE DATA: \(error.localizedDescription)")
        }
        return entity
    }
}
