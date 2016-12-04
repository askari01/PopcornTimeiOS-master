

import UIKit
import PopcornKit

protocol SubtitlesTableViewControllerDelegate: class {
    func didSelectASubtitle(_ subtitle: Subtitle?)
}

class SubtitlesTableViewController: UITableViewController {
    
    var dataSourceArray: [Subtitle]!
    weak var delegate: SubtitlesTableViewControllerDelegate?
    var selectedSubtitle: Subtitle?

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSourceArray.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = dataSourceArray[indexPath.row].language
        if let currentSubtitle = selectedSubtitle , currentSubtitle.link == dataSourceArray[indexPath.row].link {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        if cell.accessoryType == .checkmark // If selected cell is already the current subtitle, the user wants to remove subtitles
        {
            tableView.deselectRow(at: indexPath, animated: true)
            delegate?.didSelectASubtitle(nil)
            tableView.reloadData()
            return
        }
        delegate?.didSelectASubtitle(dataSourceArray[indexPath.row])
        dismiss(animated: true, completion: nil)
    }
}

extension PCTPlayerViewController {
    func didSelectASubtitle(_ subtitle: Subtitle?) {
        currentSubtitle = subtitle
    }
}
