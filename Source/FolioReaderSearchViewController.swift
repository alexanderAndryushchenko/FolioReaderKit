//
//  FolioReaderSearchViewController.swift
//  FolioReaderKit
//
//  Created by Alexander on 5/23/18.
//  Copyright © 2018 FolioReader. All rights reserved.
//


import UIKit

class FolioReaderSearchViewController: UITableViewController {
    
    var readerConfig: FolioReaderConfig!
    var folioReader: FolioReader!
    
    private let cellIdentifier = "SearchCell"
    
    var results: [FRSearchResult] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    let searchController = UISearchController(searchResultsController: nil)
    
    init(withReaderConfig readerConfig: FolioReaderConfig, folioReader: FolioReader) {
        self.readerConfig = readerConfig
        self.folioReader = folioReader
        super.init(nibName: nil, bundle: Bundle.frameworkBundle())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("This class doesn't support NSCoding.")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        
        configureSearchBar()
        configureNavBar()
        configureNavBarButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        configureNavBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.searchController.isActive = true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return folioReader.isNight(.lightContent, .default)
        
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let  cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        
        cell.textLabel?.attributedText = results[indexPath.row].resultString
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let result = results[indexPath.row]
        
        dismiss {
            self.folioReader.readerCenter?.changePageWith(href: result.resource.href, animated: false) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let webView = self.folioReader.readerCenter?.currentPage?.webView
                    webView?.highlight(string: result.searchString, withId: result.resource.id)
                }
                
            }
        }
    }
    
}

extension FolioReaderWebView {
    
    @discardableResult
    func highlight(string: String, withId id: String) -> String? {
        return js("""
            var span = "<span name='\(id)' style='background-color: rgba(255, 255, 0, 0.8); color: blue; padding: 3px 5px; box-shadow: 0px 0px 8px 3px rgba(179,179,179,0.7); border-radius: 8px; font-size: 1.05em;'><strong>\(string)</strong></span>";
            document.body.innerHTML = document.body.innerHTML.replace(/\(string)/ig, span);
            document.getElementsByName('\(id)')[0].scrollIntoView(true);
            """)
    }
    
}

// MARK: - Helpers & Actions
extension FolioReaderSearchViewController {
    
    func configureSearchBar() {
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        
        if #available(iOS 9.1, *) {
            searchController.obscuresBackgroundDuringPresentation = true
        }
        searchController.searchBar.placeholder = readerConfig.localizedSearchControllerPlaceholder
        
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            navigationItem.titleView = searchController.searchBar
            searchController.hidesNavigationBarDuringPresentation = false
        }
        definesPresentationContext = true
        searchController.searchBar.delegate = self
    }
    
    func configureNavBar() {
        navigationItem.title = readerConfig.localizedSearchControllerTitle
        
        let navBackground = folioReader.isNight(self.readerConfig.nightModeMenuBackground, UIColor.white)
        let tintColor = readerConfig.tintColor
        let navText = folioReader.isNight(UIColor.white, UIColor.black)
        let font = UIFont(name: "Avenir-Light", size: 17)!
        
        let searchBar = searchController.searchBar
        let navBar = navigationController?.navigationBar
        
        searchBar.setBackgroundImage(UIImage.imageWithColor(navBackground), for: .any, barMetrics: UIBarMetrics.default)
        searchBar.isTranslucent = true
        searchBar.tintColor = tintColor
        searchBar.barTintColor = tintColor
        searchBar.backgroundColor = navBackground
        searchBar.barStyle = folioReader.isNight(.black, .default)
        navBar?.barTintColor = navBackground
        navBar?.isTranslucent = false
        navBar?.titleTextAttributes = [NSForegroundColorAttributeName: tintColor, NSFontAttributeName: font]
    }
    
    func configureNavBarButtons() {
        let closeIcon = UIImage(readerImageNamed: "icon-navbar-close")?.ignoreSystemTint(withConfiguration: self.readerConfig)
        
        let menu = UIBarButtonItem(image: closeIcon, style: .plain, target: self, action:#selector(closeSearch(_:)))
        navigationItem.leftBarButtonItem = menu
    }
    
    @objc func closeSearch(_ sender: UIBarButtonItem) {
        dismiss()
    }
    
}

// MARK: - UISearchControllerDelegate
extension FolioReaderSearchViewController: UISearchControllerDelegate {
    
    func didPresentSearchController(_ searchController: UISearchController) {
        DispatchQueue.main.async {
            self.searchController.searchBar.becomeFirstResponder()
        }
    }
    
}

// MARK: - UISearchBarDelegate
extension FolioReaderSearchViewController: UISearchBarDelegate { }

// MARK: - UISearchResultsUpdating
extension FolioReaderSearchViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        guard !text.isEmpty else { return }
        results = searchEntireBook(for: text)
    }
    
}

// MARK: - Search
extension FolioReaderSearchViewController {
    
    private func regexPattern(for searchString: String) -> String {
        return "([\n\r]+){0,0}\(searchString)([^\u{0000}-\u{007F}]|\\w){0,0}"
    }
    
    private func regex(for searchString: String) -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: regexPattern(for: searchString), options: [])
    }
    
    func searchEntireBook(for searchString: String) -> [FRSearchResult] {
        guard !searchString.isEmpty else { return [] }
        guard let totalPages = folioReader.readerCenter?.totalPages else { return [] }
        guard let book = folioReader.readerContainer?.book else { return [] }
        
        guard let regex = regex(for: searchString) else { return [] }
        
        var results: [FRSearchResult] = []
        
        for pageNumber in 0..<totalPages {
            let resource = book.spine.spineReferences[pageNumber].resource!
            let href = resource.href
            
            guard let htmlString = try? String(contentsOfFile: resource.fullHref, encoding: .utf8).stripHtml() else { continue }
            
            let matches = regex.matches(in: htmlString, options: .reportProgress, range: NSMakeRange(0, htmlString.utf16.count))
            matches.forEach { results.append(FRSearchResult(searchString: searchString, resource: resource, range: $0.range)) }
        }
        
        return results
    }
    
}
