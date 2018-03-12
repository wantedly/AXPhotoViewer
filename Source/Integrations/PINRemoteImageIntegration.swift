//
//  PINRemoteImageIntegration.swift
//  AXPhotoViewer
//
//  Created by Alex Hill on 6/1/17.
//  Copyright © 2017 Alex Hill. All rights reserved.
//

#if canImport(PINRemoteImage)
    
import PINRemoteImage

class PINRemoteImageIntegration: NSObject, AXNetworkIntegrationProtocol {

    weak var delegate: AXNetworkIntegrationDelegate?
    
    fileprivate var downloadUUIDs = NSMapTable<AXPhotoProtocol, NSUUID>(keyOptions: .strongMemory, valueOptions: .strongMemory)
    
    func loadPhoto(_ photo: AXPhotoProtocol) {
        if photo.imageData != nil || photo.image != nil {
            self.delegate?.networkIntegration(self, loadDidFinishWith: photo)
        }
        
        guard let url = photo.url else {
            return
        }
        
        let progress: PINRemoteImageManagerProgressDownload = { [weak self] (completedBytes, totalBytes) in
            guard let `self` = self else {
                return
            }
            
            self.delegate?.networkIntegration?(self, didUpdateLoadingProgress: CGFloat(completedBytes) / CGFloat(totalBytes), for: photo)
        }
        
        let completion: PINRemoteImageManagerImageCompletion = { [weak self] (result) in
            guard let `self` = self else {
                return
            }
            
            self.downloadUUIDs.removeObject(forKey: photo)
            
            if let animatedImage = result.alternativeRepresentation as? FLAnimatedImage {
                // this is not great, as `PINRemoteImage` already creates the `FLAnimatedImage` that we need.
                // something to fix in the future.
                photo.imageData = animatedImage.data
                self.delegate?.networkIntegration(self, loadDidFinishWith: photo)
            } else if let image = result.image {
                photo.image = image
                self.delegate?.networkIntegration(self, loadDidFinishWith: photo)
            } else {
                let error = NSError(
                    domain: AXNetworkIntegrationErrorDomain,
                    code: AXNetworkIntegrationFailedToLoadErrorCode,
                    userInfo: nil
                )
                self.delegate?.networkIntegration(self, loadDidFailWith: error, for: photo)
            }
        }
        
        guard let uuid = PINRemoteImageManager.shared().downloadImage(with: url, options: [], progressDownload: progress, completion: completion) else {
            return
        }
        
        self.downloadUUIDs.setObject(uuid as NSUUID, forKey: photo)
    }
    
    func cancelLoad(for photo: AXPhotoProtocol) {
        guard let uuid = self.downloadUUIDs.object(forKey: photo) else {
            return
        }
        
        PINRemoteImageManager.shared().cancelTask(with: uuid as UUID, storeResumeData: true)
    }
    
    func cancelAllLoads() {
        let enumerator = self.downloadUUIDs.objectEnumerator()
        
        while let uuid  = enumerator?.nextObject() as? NSUUID {
            PINRemoteImageManager.shared().cancelTask(with: uuid as UUID, storeResumeData: true)
        }
        
        self.downloadUUIDs.removeAllObjects()
    }
    
}

#endif
