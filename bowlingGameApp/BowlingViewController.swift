//
//  BowlingViewController.swift
//  bowlingGameApp
//
//  Created by Laura Antelo Gonzalez on 10/4/26.
//

import UIKit

class BowlingViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    
    @IBOutlet weak var framesCollectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    
    private struct RollInfo {
        let globalIndex: Int
        let pins: Int
    }
    
    private struct FrameInfo {
        let number: Int
        let rolls: [RollInfo]
        
        var frameScore: Int {
            rolls.reduce(0) { $0 + $1.pins }
        }
    }
    
    private enum ErrorPartida: LocalizedError {
        case tiradaFueraDeRango
        case frameInvalido(Int)
        case decimoFrameInvalido
        case demasiadasTiradas
        
        var errorDescription: String? {
            switch self {
            case .tiradaFueraDeRango:
                return "La tirada debe estar entre 0 y 10."
            case .frameInvalido(let frame):
                return "La suma de tiradas del Frame \(frame) no puede superar 10."
            case .decimoFrameInvalido:
                return "Las tiradas del Frame 10 no cumplen las reglas."
            case .demasiadasTiradas:
                return "La partida ya no admite más tiradas."
            }
        }
    }
    
    private var rolls: [Int] = []
    private var frames: [FrameInfo] = []
    private var selectedFrameIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addRollTapped))
        
        navigationItem.rightBarButtonItem = editButtonItem
        
        frames = (try? buildFrames(from: rolls)) ?? [FrameInfo(number: 1, rolls: [])]
        reloadUI()
    }

    @objc func addRollTapped(_ sender: UIBarButtonItem) {
        guard let currentFrame = frames.last else { return }
        
        let alert = UIAlertController(
            title: "Nueva tirada",
            message: "Añadir tirada al Frame \(currentFrame.number)",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Número de bolos (0...10)"
            textField.keyboardType = .numberPad
        }
        
        let addAction = UIAlertAction(title: "Añadir", style: .default) { _ in
            guard let text = alert.textFields?.first?.text,
                  let pins = Int(text) else {
                return
            }
            
            var candidate = self.rolls
            candidate.append(pins)
            self.applyCandidateRolls(candidate)
            
            self.selectedFrameIndex = max(0, self.frames.count - 1)
            
            self.reloadCollectionSelection()
        }

        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(addAction)
        
        present(alert, animated: true)
    }

    private func reloadUI() {
        updateNavigationInfo()
        tableView.reloadData()
        framesCollectionView.reloadData()
        reloadCollectionSelection()
    }

    private func reloadCollectionSelection() {
        guard frames.indices.contains(selectedFrameIndex) else { return }
        
        framesCollectionView.layoutIfNeeded()
        
        let indexPath = IndexPath(item: selectedFrameIndex, section: 0)
        framesCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredHorizontally)
    }

    private func updateNavigationInfo() {
        navigationItem.title = "Puntuación total: \(totalScore())"
    }

    private func showError(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        
        let alert = UIAlertController(
            title: "Operación no válida",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func applyCandidateRolls(_ candidate: [Int]) {
        do {
            let newFrames = try buildFrames(from: candidate)
            rolls = candidate
            frames = newFrames
            
            if selectedFrameIndex >= frames.count {
                selectedFrameIndex = max(0, frames.count - 1)
            }
            
            reloadUI()
        } catch {
            showError(error)
            reloadUI()
        }
    }

    private func scrollToFrame(section: Int) {
        guard frames.indices.contains(section) else { return }
        
        tableView.layoutIfNeeded()
        
        if frames[section].rolls.isEmpty {
            let rect = tableView.rect(forSection: section)
            tableView.setContentOffset(CGPoint(x: 0, y: rect.minY), animated: true)
        } else {
            let indexPath = IndexPath(row: 0, section: section)
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }

    private func flatPosition(for indexPath: IndexPath) -> Int {
        var position = 0
        
        for section in 0..<indexPath.section {
            position += frames[section].rolls.count
        }
        
        position += indexPath.row
        return position
    }

    private func buildFrames(from candidateRolls: [Int]) throws -> [FrameInfo] {
        var result: [FrameInfo] = []
        var index = 0

        for frameNumber in 1...10 {

            if index >= candidateRolls.count {
                result.append(FrameInfo(number: frameNumber, rolls: []))
                return result
            }

            let first = candidateRolls[index]

            guard (0...10).contains(first) else {
                throw ErrorPartida.tiradaFueraDeRango
            }

            if frameNumber < 10 {

                if first == 10 {
                    result.append(
                        FrameInfo(
                            number: frameNumber,
                            rolls: [
                                RollInfo(globalIndex: index, pins: first)
                            ]
                        )
                    )
                    index += 1
                    continue
                }

                if index + 1 >= candidateRolls.count {
                    result.append(
                        FrameInfo(
                            number: frameNumber,
                            rolls: [
                                RollInfo(globalIndex: index, pins: first)
                            ]
                        )
                    )
                    return result
                }

                let second = candidateRolls[index + 1]

                guard (0...10).contains(second) else {
                    throw ErrorPartida.tiradaFueraDeRango
                }

                guard first + second <= 10 else {
                    throw ErrorPartida.frameInvalido(frameNumber)
                }

                result.append(
                    FrameInfo(
                        number: frameNumber,
                        rolls: [
                            RollInfo(globalIndex: index, pins: first),
                            RollInfo(globalIndex: index + 1, pins: second)
                        ]
                    )
                )

                index += 2
                continue
            }

            var tenthRolls: [RollInfo] = [
                RollInfo(globalIndex: index, pins: first)
            ]

            if index + 1 >= candidateRolls.count {
                result.append(FrameInfo(number: frameNumber, rolls: tenthRolls))
                return result
            }

            let second = candidateRolls[index + 1]

            guard (0...10).contains(second) else {
                throw ErrorPartida.tiradaFueraDeRango
            }

            if first != 10 && first + second > 10 {
                throw ErrorPartida.decimoFrameInvalido
            }

            tenthRolls.append(RollInfo(globalIndex: index + 1, pins: second))

            if first != 10 && first + second < 10 {
                result.append(FrameInfo(number: frameNumber, rolls: tenthRolls))

                if index + 2 < candidateRolls.count {
                    throw ErrorPartida.demasiadasTiradas
                }

                return result
            }

            if index + 2 >= candidateRolls.count {
                result.append(FrameInfo(number: frameNumber, rolls: tenthRolls))
                return result
            }

            let third = candidateRolls[index + 2]

            guard (0...10).contains(third) else {
                throw ErrorPartida.tiradaFueraDeRango
            }

            if first == 10 && second != 10 && second + third > 10 {
                throw ErrorPartida.decimoFrameInvalido
            }

            tenthRolls.append(RollInfo(globalIndex: index + 2, pins: third))
            result.append(FrameInfo(number: frameNumber, rolls: tenthRolls))

            if index + 3 < candidateRolls.count {
                throw ErrorPartida.demasiadasTiradas
            }

            return result
        }

        if index < candidateRolls.count {
            throw ErrorPartida.demasiadasTiradas
        }

        return result
    }

    private func totalScore() -> Int {
        var total = 0
        var rollIndex = 0
        var frame = 1

        while frame <= 10 && rollIndex < rolls.count {
            if rolls[rollIndex] == 10 {
                if rollIndex + 2 < rolls.count {
                    total += 10 + rolls[rollIndex + 1] + rolls[rollIndex + 2]
                } else {
                        total += 10
                    }

                rollIndex += 1
                
            } else if rollIndex + 1 < rolls.count {
                    let frameScore = rolls[rollIndex] + rolls[rollIndex + 1]

                    if frameScore == 10 {
                        if rollIndex + 2 < rolls.count {
                            total += 10 + rolls[rollIndex + 2]
                        } else {
                                total += 10
                            }
                    } else {
                            total += frameScore
                        }

                    rollIndex += 2
                    
                } else {
                        total += rolls[rollIndex]
                        rollIndex += 1
                    }

            frame += 1
        }

        return total
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int {
        return frames.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return frames[section].rolls.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Frame \(frames[section].number)"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Puntuación del frame: \(frames[section].frameScore)"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RollCell", for: indexPath)

        let roll = frames[indexPath.section].rolls[indexPath.row]
        cell.textLabel?.text = "Tirada \(indexPath.row + 1): \(roll.pins)"
        cell.showsReorderControl = true
        
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        guard editingStyle == .delete else { return }
        
        let roll = frames[indexPath.section].rolls[indexPath.row]
        
        var candidate = rolls
        candidate.remove(at: roll.globalIndex)

        applyCandidateRolls(candidate)
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        let sourceRoll = frames[sourceIndexPath.section].rolls[sourceIndexPath.row]
        let movingPins = sourceRoll.pins
        
        var candidate = rolls
        candidate.remove(at: sourceRoll.globalIndex)
        
        let destinationFlatIndex = flatPosition(for: destinationIndexPath)
        let safeDestination = min(destinationFlatIndex, candidate.count)

        candidate.insert(movingPins, at: safeDestination)

        applyCandidateRolls(candidate)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let roll = frames[indexPath.section].rolls[indexPath.row]

        let alert = UIAlertController(
            title: "Editar tirada",
            message: "Frame \(frames[indexPath.section].number)",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.text = "\(roll.pins)"
            textField.keyboardType = .numberPad
        }
        
        let saveAction = UIAlertAction(title: "Guardar", style: .default) { _ in
            guard let text = alert.textFields?.first?.text,
                  let newPins = Int(text) else { return }
            
            var candidate = self.rolls
            candidate[roll.globalIndex] = newPins
            
            self.applyCandidateRolls(candidate)
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(saveAction)
        present(alert, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - CollectionView
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return frames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FrameCell", for: indexPath) as! FrameCollectionViewCell
        cell.frameLabel.text = "Frame \(frames[indexPath.item].number)"
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedFrameIndex = indexPath.item
        scrollToFrame(section: indexPath.item)
    }
}
