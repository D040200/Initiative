// SquareView.swift
import SwiftUI

struct SquareView: View {
    let square: Square
    let piece: Piece?
    
    private var squareColor: Color {
        let isLight = (square.file.rawValue + square.rank.rawValue) % 2 == 0
        return isLight ? Color(red: 0.9, green: 0.85, blue: 0.76) : Color(red: 0.7, green: 0.5, blue: 0.3)
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(squareColor)
            
            if let piece = piece {
                Image(piece.imageName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
// Optional: A preview for just the SquareView
struct SquareView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SquareView(square: Square(file: .E, rank: .four), piece: Piece(type: .knight, color: .white))
                .previewLayout(.sizeThatFits)
                .frame(width: 80, height: 80)
            
            SquareView(square: Square(file: .D, rank: .four), piece: nil)
                .previewLayout(.sizeThatFits)
                .frame(width: 80, height: 80)
        }
    }
}
