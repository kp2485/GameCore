GameDataSwiftData


SwiftData-backed persistence for Fizzle’s GameCore.
    •    Entities for Races, Classes, Characters, Items, Equipment Slots, and Game Saves.
    •    Repositories: SDRaceRepository, SDClassRepository, SDItemRepository, SDLoadoutStore, SDGameSaveRepository.
    •    Facade: GameSaveService with GameStateProvider to snapshot/load party state.
    •    JSON Import/Export for content seeding (JSONImporter/JSONExporter + bundle I/O).
    •    All APIs @MainActor, portable via #if canImport(SwiftData).


Quick start:

let stack = try SDStack(inMemory: false)
let races  = SDRaceRepository(stack: stack)
let classes = SDClassRepository(stack: stack)
let items   = SDItemRepository(stack: stack)
try DefaultSeed.seedBasicContent(races: races, classes: classes, items: items)

let saveRepo = SDGameSaveRepository(stack: stack)
let provider = ClosureGameStateProvider(
  members: { currentParty },
  equipmentBy: { equipment[$0] },
  inventoryBy: { inventories[$0] ?? [:] }
)
let service  = GameSaveService(repo: saveRepo, provider: provider)
let saveId = try service.saveCurrentGame(name: "Start")
let loaded = try service.loadGame(id: saveId)


Platforms

iOS 17+ / macOS 14+ (SwiftData). Core logic remains portable in GameCore.
