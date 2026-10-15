import SwiftUI

struct ContentView: View {
    @State private var showMessage = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Моё первое приложение")
                .font(.title)
                .fontWeight(.bold)
                .padding()
            
            Button(action: {
                showMessage = true
            }) {
                Text("Hello world")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .cornerRadius(15)
            }
        }
        .alert("Hi world", isPresented: $showMessage) {
            Button("OK", role: .cancel) { }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}