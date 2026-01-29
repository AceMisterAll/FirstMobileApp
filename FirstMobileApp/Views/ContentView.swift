import SwiftUI
import MapKit
import Combine

struct ContentView: View {
    @State private var isformCreateUser: Bool = false
    @State private var users: [User] = []
    @State private var name: String = ""
    @State private var title: String = ""
    @State private var localisation: String = ""
    @StateObject private var villeAutocomplete = VilleAutocomplete()
    @State private var selectedUserID: UUID? = nil
    @State private var isPickingSuggestion: Bool = false
    
    private func loadUsers() {
        users = UserStore.load()
    }
    
    @ViewBuilder
    private func userList() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(users) { user in
                UserRowView(
                    user: user,
                    isSelected: selectedUserID == user.id,
                    onSelect: {
                        selectedUserID = (selectedUserID == user.id) ? nil : user.id
                    },
                    onDelete: {
                        users.removeAll { $0.id == user.id }
                        if selectedUserID == user.id { selectedUserID = nil }
                    }
                )
                .padding(.horizontal)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                userList()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isformCreateUser = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        
        .sheet(isPresented: $isformCreateUser) {
            Form {
                Section(header: Text("Informations")) {
                    TextField("Nom", text: $name)
                    TextField("Titre", text: $title)
                    TextField("Ville", text: $localisation)
                        .onChange(of: localisation) { _, nouvelleValeur in
                            if isPickingSuggestion {
                                // Ignore the programmatic change caused by selecting a suggestion
                                isPickingSuggestion = false
                                return
                            }
                            // User is typing: refresh suggestions
                            villeAutocomplete.update(query: nouvelleValeur)
                        }
                    if !villeAutocomplete.suggestions.isEmpty {
                        List(villeAutocomplete.suggestions, id: \.self) { suggestion in
                            Button(action: {
                                isPickingSuggestion = true
                                localisation = suggestion.title
                                villeAutocomplete.suggestions = []
                            }) {
                                VStack(alignment: .leading) {
                                    Text(suggestion.title)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(height: 150) // (optionnel) limite la hauteur de la liste
                        .listStyle(.plain)
                    }
                }
                Section {
                    Button("Ajouter") {
                        users.append(
                            User(
                                name: name,
                                title: title,
                                localisation: localisation,
                                avatarSystemImage: "person.crop.circle.fill"
                            )
                        )
                        isformCreateUser = false
                        name = ""
                        title = ""
                        localisation = ""
                        villeAutocomplete.suggestions = []
                    }
                    .disabled(name.isEmpty || title.isEmpty || localisation.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear(perform: loadUsers)
        .onChange(of: users) { _, newValue in
            UserStore.save(newValue)
        }
        .onChange(of: isformCreateUser) { _, isPresented in
            if !isPresented {
                villeAutocomplete.suggestions = []
            } else {
                villeAutocomplete.suggestions = []
            }
        }
    }
}

class VilleAutocomplete: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private var completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        
        // On dit à MapKit : je veux uniquement des adresses
        completer.resultTypes = .address
        // On écoute les changements de suggestion
        completer.delegate = self
    }

    // À chaque frappe au clavier, on actualise la recherche
    func update(query: String) {
        completer.queryFragment = query
    }
}

// On déclare qu’on veut être alerté quand MapKit a de nouveaux résultats
extension VilleAutocomplete: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

struct User: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name : String
    var title : String
    var localisation : String
    let avatarSystemImage: String
}

struct PersonCard: View {
    let name: String
    let title: String
    let location: String
    let avatarSystemImage: String

    // Nouveaux paramètres
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: avatarSystemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                    Text(location)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Bouton supprimer dans la carte
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.red.opacity(0.8)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            // Fond “carte” en material
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 6)
                    .blur(radius: 8)
                    .opacity(0.5)
            }
        }
        .overlay(
            // Contour élégant
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color(.separator).opacity(0.4),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.25) : Color.black.opacity(0.08),
            radius: isSelected ? 14 : 12,
            x: 0, y: isSelected ? 8 : 6
        )
        .contentShape(Rectangle()) // toute la carte est cliquable
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct UserRowView: View {
    let user: User
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        PersonCard(
            name: user.name,
            title: user.title,
            location: user.localisation,
            avatarSystemImage: user.avatarSystemImage,
            isSelected: isSelected,
            onSelect: onSelect,
            onDelete: onDelete
        )
    }
}

enum UserStore {
    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("users.json")
    }

    static func load() -> [User] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([User].self, from: data)
        } catch {
            // Fichier absent ou erreur -> on retourne une liste vide
            return []
        }
    }

    static func save(_ users: [User]) {
        do {
            let data = try JSONEncoder().encode(users)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Pour débuter, on peut ignorer l’erreur ou l’imprimer
            print("Erreur de sauvegarde:", error)
        }
    }
}

#Preview {
    ContentView()
}

// Class User


