

import Foundation
import GoogleCast
import PopcornKit

typealias CastMetaData = (title: String, image: URL?, contentType: String, subtitles: [Subtitle]?, url: String, mediaAssetsPath: URL)

class GoogleCastManager: NSObject, GCKDeviceScannerListener, GCKSessionManagerListener {
    
    var dataSourceArray = [GCKDevice]()
    weak var delegate: ConnectDevicesProtocol?
    
    var deviceScanner: GCKDeviceScanner!
    
    /// If a user is connected to a device and wants to connect to another, a queue has to be made as the disconnect operation is asyncronous. When the user has successfully disconnected from the first device, this device should then be connected to.
    private var deviceAwaitingConnection: GCKDevice?
    var castMetadata: CastMetaData?
    
    override init() {
        super.init()
        deviceScanner = GCKDeviceScanner(filterCriteria: GCKFilterCriteria(forAvailableApplicationWithID: kGCKMediaDefaultReceiverApplicationID))
        deviceScanner!.add(self)
        deviceScanner!.startScan()
        GCKCastContext.sharedInstance().sessionManager.add(self)
    }
    
    /// If you chose to initialise with this method, no delegate requests will be recieved.
    init(castMetadata: CastMetaData) {
        super.init()
        self.castMetadata = castMetadata
    }
    
    func didSelectRoute(_ device: GCKDevice, castMetadata: CastMetaData? = nil) {
        self.castMetadata = castMetadata
        if let session = GCKCastContext.sharedInstance().sessionManager.currentSession {
            GCKCastContext.sharedInstance().sessionManager.endSession()
            if session.device != device {
               deviceAwaitingConnection = device
            }
        } else {
            GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
        }
    }
    
    // MARK: - GCKDeviceScannerListener
    
    func deviceDidComeOnline(_ device: GCKDevice) {
        dataSourceArray.append(device)
        delegate?.updateTableView(dataSource: dataSourceArray, updateType: .insert, indexPaths: [IndexPath(row: dataSourceArray.count - 1, section: 1)])
    }
    

    func deviceDidGoOffline(_ device: GCKDevice) {
        for (index, oldDevice) in dataSourceArray.enumerated() {
            if device === oldDevice {
                dataSourceArray.remove(at: index)
                delegate?.updateTableView(dataSource: dataSourceArray, updateType: .delete, indexPaths: [IndexPath(row: index, section: 1)])
            }
        }
    }
    
    func deviceDidChange(_ device: GCKDevice) {
        for (index, oldDevice) in dataSourceArray.enumerated() {
            if device === oldDevice {
                dataSourceArray[index] = device
                delegate?.updateTableView(dataSource: dataSourceArray, updateType: .reload, indexPaths: [IndexPath(row: index, section: 1)])
            }
        }
    }
    
    // MARK: - GCKSessionManagerListener
    
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        guard error == nil else { return }
        if let device = deviceAwaitingConnection {
            GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
        } else {
            delegate?.didConnectToDevice(deviceIsChromecast: true)
        }
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        if let castMetadata = castMetadata {
            if let subtitles = castMetadata.subtitles {
                var mediaTracks = [GCKMediaTrack]()
                for (index, subtitle) in subtitles.enumerated() {
                    mediaTracks.append(GCKMediaTrack(identifier: index, contentIdentifier: castMetadata.mediaAssetsPath.appendingPathComponent("Subtitles", isDirectory: true).appendingPathComponent(subtitle.ISO639 + ".vtt").relativeString, contentType: "text/vtt", type: .text, textSubtype: .captions, name: subtitle.language, languageCode: subtitle.ISO639, customData: nil))
                }
                self.streamToDevice(mediaTracks, sessionManager: sessionManager, castMetadata: castMetadata)
                self.delegate?.didConnectToDevice(deviceIsChromecast: true)
            } else {
                streamToDevice(sessionManager: sessionManager, castMetadata: castMetadata)
                delegate?.didConnectToDevice(deviceIsChromecast: true)
            }
        } else {
            delegate?.didConnectToDevice(deviceIsChromecast: true)
        }
    }
    
    func streamToDevice(_ mediaTrack: [GCKMediaTrack]? = nil, sessionManager: GCKSessionManager, castMetadata: CastMetaData) {
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(castMetadata.title, forKey: kGCKMetadataKeyTitle)
        if let url = castMetadata.image {
            metadata.addImage(GCKImage(url: url as URL, width: 480, height: 720))
        }
        let mediaInfo = GCKMediaInformation(contentID: castMetadata.url, streamType: .buffered, contentType: castMetadata.contentType, metadata: metadata, streamDuration: 0, mediaTracks: nil, textTrackStyle: GCKMediaTextTrackStyle.createDefault(), customData: nil)
        sessionManager.currentCastSession?.remoteMediaClient?.loadMedia(mediaInfo, autoplay: true)
    }

    
    deinit {
        if let deviceScanner = deviceScanner , deviceScanner.scanning {
            deviceScanner.stopScan()
            deviceScanner.remove(self)
            GCKCastContext.sharedInstance().sessionManager.remove(self)
        }
        deviceAwaitingConnection = nil
        castMetadata = nil
    }
    
}

func == (left: GCKDevice, right: GCKDevice) -> Bool {
    return left.deviceID == right.deviceID && left.uniqueID == right.uniqueID
}

func != (left: GCKDevice, right: GCKDevice) -> Bool {
    return left.deviceID != right.deviceID && left.uniqueID != right.uniqueID
}
