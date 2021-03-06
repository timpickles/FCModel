//
//  AppDelegate.m
//  FCModelTest
//
//  Created by Marco Arment on 9/14/13.
//  Copyright (c) 2013 Marco Arment. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "FCModel.h"
#import "Person.h"
#import "RandomThings.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"testDB.sqlite3"];
    NSLog(@"DB path: %@", dbPath);

    // New DB on every launch for testing (comment out for persistence testing)
    [NSFileManager.defaultManager removeItemAtPath:dbPath error:NULL];
    
#ifdef TEST_CLASS_PREFIX
    [FCModel setClassPrefix:@"FC"];
#endif
    [FCModel openDatabaseAtPath:dbPath withSchemaBuilder:^(FMDatabase *db, int *schemaVersion) {
        [db setCrashOnErrors:YES];
        db.traceExecution = YES; // Log every query (useful to learn what FCModel is doing or analyze performance)
        [db beginTransaction];
        
        void (^failedAt)(int statement) = ^(int statement){
            [db rollback];
            NSAssert3(0, @"Migration statement %d failed, code %d: %@", statement, db.lastErrorCode, db.lastErrorMessage);
        };

        if (*schemaVersion < 1) {
            if (! [db executeUpdate:
                @"CREATE TABLE Person ("
                @"    id           INTEGER PRIMARY KEY AUTOINCREMENT," // Autoincrement is optional. Just demonstrating that it works.
                @"    name         TEXT NOT NULL DEFAULT '',"
                @"    colorName    TEXT NOT NULL,"
                @"    taps         INTEGER NOT NULL DEFAULT 0,"
                @"    createdTime  INTEGER NOT NULL,"
                @"    modifiedTime INTEGER NOT NULL"
                @");"
            ]) failedAt(1);
            if (! [db executeUpdate:@"CREATE UNIQUE INDEX IF NOT EXISTS name ON Person (name);"]) failedAt(2);

            if (! [db executeUpdate:
                @"CREATE TABLE Color ("
                @"    name         TEXT NOT NULL PRIMARY KEY,"
                @"    hex          TEXT NOT NULL"
                @");"
            ]) failedAt(3);

            // Create any other tables...
            
            *schemaVersion = 1;
        }

        // If you wanted to change the schema in a later app version, you'd add something like this here:
        /*
        if (*schemaVersion < 2) {
            if (! [db executeUpdate:@"ALTER TABLE Person ADD COLUMN lastModified INTEGER NULL"]) failedAt(3);
            *schemaVersion = 2;
        }
        */

        [db commit];
    }];
    

    // Prepopulate the Color table
    [@{
        @"red" : @"FF3838",
        @"orange" : @"FF9335",
        @"yellow" : @"FFC947",
        @"green" : @"44D875",
        @"blue1" : @"2DAAD6",
        @"blue2" : @"007CF4",
        @"purple" : @"5959CE",
        @"pink" : @"FF2B56",
        @"gray1" : @"8E8E93",
        @"gray2" : @"C6C6CC",
    } enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *hex, BOOL *stop) {
        COLOR_CLASS *c = [COLOR_CLASS instanceWithPrimaryKey:name];
        c.hex = hex;
        [c save];
    }];
    
    NSArray *allColors = [COLOR_CLASS allInstances];

    // Comment/uncomment this to see caching/retention behavior.
    // Without retaining these, scroll the collectionview, and you'll see each cell performing a SELECT to look up its color.
    // By retaining these, all of the colors are kept in memory by primary key, and those requests become cache hits.
    self.cachedColors = allColors;
    
    NSMutableSet *colorsUsedAlready = [NSMutableSet set];
    
    // Put some data in the table if there's not enough
    int numPeople = [[PERSON_CLASS firstValueFromQuery:@"SELECT COUNT(*) FROM $T"] intValue];
    while (numPeople < 26) {
        PERSON_CLASS *p = [PERSON_CLASS new];
        p.name = [RandomThings randomName];
        
        if (colorsUsedAlready.count >= allColors.count) [colorsUsedAlready removeAllObjects];
        
        COLOR_CLASS *color;
        do {
            color = (COLOR_CLASS *) allColors[([RandomThings randomUInt32] % allColors.count)];
        } while ([colorsUsedAlready member:color] && colorsUsedAlready.count < allColors.count);

        [colorsUsedAlready addObject:color];
        p.color = color;
        
        if ([p save]) numPeople++;
    }
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
							
@end
