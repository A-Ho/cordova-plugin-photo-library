import Photos
import Foundation

//TODO: Swift 3
//extension NSDate: JSONRepresentable {
//    var JSONRepresentation: AnyObject {
//        let formatter = NSDateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
//
//        return formatter.stringFromDate(self)
//    }
//}
//extension NSURL: JSONRepresentable {
//    var JSONRepresentation: AnyObject {
//        return self.absoluteString
//    }
//}

final class PhotoLibraryService {
    
    let fetchOptions: PHFetchOptions!
    let imageRequestOptions: PHImageRequestOptions!
    let dateFormatter: NSDateFormatter! //TODO: remove in Swift 3, use JSONRepresentable
    let cachingImageManager: PHCachingImageManager!
    
    let contentMode = PHImageContentMode.AspectFill // AspectFit: can be smaller, AspectFill - can be larger. TODO: resize to exact size
    
    private init() {
        fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if #available(iOS 9.0, *) {
            fetchOptions.includeAssetSourceTypes = [.TypeUserLibrary, .TypeiTunesSynced, .TypeCloudShared]
        }
        
        imageRequestOptions = PHImageRequestOptions()
        imageRequestOptions.synchronous = true
        imageRequestOptions.resizeMode = .Fast
        imageRequestOptions.deliveryMode = .FastFormat
        imageRequestOptions.version = .Current
        
        dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        
        cachingImageManager = PHCachingImageManager()
    }
    
    class var instance: PhotoLibraryService {
        struct SingletonWrapper {
            static let singleton = PhotoLibraryService()
        }
        return SingletonWrapper.singleton
    }
    
    func getLibrary(thumbnailWidth: Int, thumbnailHeight: Int) -> [NSDictionary] {
        
        let fetchResult = PHAsset.fetchAssetsWithMediaType(.Image, options: self.fetchOptions)
        
        var library = [NSDictionary]()
        
        var assets = [PHAsset]()
        fetchResult.enumerateObjectsUsingBlock{ (obj, idx: Int, stop: UnsafeMutablePointer<ObjCBool>) in
            assets.append(obj as! PHAsset)
        }
        
        do {
            try self.stopCaching()
        } catch { }
        self.cachingImageManager.startCachingImagesForAssets(assets, targetSize: CGSize(width: thumbnailWidth, height: thumbnailHeight), contentMode: self.contentMode, options: self.imageRequestOptions)
        
        assets.forEach { (asset: PHAsset) in
            
            PHImageManager.defaultManager().requestImageDataForAsset(asset, options: self.imageRequestOptions) {
                (imageData: NSData?, dataUTI: String?, orientation: UIImageOrientation, info: [NSObject : AnyObject]?) in
                
                let imageURL = info?["PHImageFileURLKey"] as? NSURL
                
                let libraryItem = NSMutableDictionary()
                
                libraryItem["id"] = asset.localIdentifier
                libraryItem["filename"] = imageURL?.pathComponents?.last
                libraryItem["nativeURL"] = imageURL?.absoluteString //TODO: in Swift 3, use JSONRepresentable
                libraryItem["width"] = asset.pixelWidth
                libraryItem["height"] = asset.pixelHeight
                libraryItem["creationDate"] = self.dateFormatter.stringFromDate(asset.creationDate!) //TODO: in Swift 3, use JSONRepresentable
                // TODO: asset.faceRegions, asset.locationData
                
                library.append(libraryItem)
            }
        }
        
        return library

    }
    
    func getThumbnail(photoId: String, thumbnailWidth: Int, thumbnailHeight: Int, quality: Float, resultCallback: (result: PictureData) -> Void) {
        
        let fetchResult = PHAsset.fetchAssetsWithLocalIdentifiers([photoId], options: self.fetchOptions)
        
        // TODO: why enumeration needed for one asset?
        fetchResult.enumerateObjectsUsingBlock {
            (obj: AnyObject, idx: Int, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            
            let asset = obj as! PHAsset
            
            self.cachingImageManager.requestImageForAsset(asset, targetSize: CGSize(width: thumbnailWidth, height: thumbnailHeight), contentMode: self.contentMode, options: self.imageRequestOptions) {
                (image: UIImage?, imageInfo: [NSObject : AnyObject]?) in
                
                let imageData = self.image2PictureData(image!, quality: quality)
                
                resultCallback(result: imageData)
            }
        }

    }
    
    func getPhoto(photoId: String, resultCallback: (result: PictureData) -> Void) {
        
        let fetchResult = PHAsset.fetchAssetsWithLocalIdentifiers([photoId], options: self.fetchOptions)
        
        fetchResult.enumerateObjectsUsingBlock {
            (obj: AnyObject, idx: Int, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            
            let asset = obj as! PHAsset
            
            PHImageManager.defaultManager().requestImageDataForAsset(asset, options: self.imageRequestOptions) {
                (imageData: NSData?, dataUTI: String?, orientation: UIImageOrientation, info: [NSObject : AnyObject]?) in
                
                let image = imageData != nil ? UIImage(data: imageData!) : nil
                
                let imageData = self.image2PictureData(image!, quality: 1.0)
                
                resultCallback(result: imageData)
            }
        }
        
    }
    
    func stopCaching() throws {
        try ObjCTry.doTry {
            self.cachingImageManager.stopCachingImagesForAllAssets()
        }
    }
    
    struct PictureData {
        var data: NSData?
        var mimeType: String?
    }
    
    private func image2PictureData(image: UIImage, quality: Float) -> PictureData {
        //        This returns raw data, but mime type is unknown. Anyway, crodova performs base64 for messageAsArrayBuffer, so there's no performance gain visible
        //        let provider: CGDataProvider = CGImageGetDataProvider(image.CGImage)!
        //        let data = CGDataProviderCopyData(provider)
        //        return data;
        
        var data: NSData?
        var mimeType: String?
        
        if (imageHasAlpha(image)){
            data = UIImagePNGRepresentation(image)
            mimeType = data != nil ? "image/png" : nil
        } else {
            data = UIImageJPEGRepresentation(image, CGFloat(quality))
            mimeType = data != nil ? "image/jpeg" : nil
        }
        
        return PictureData(data: data, mimeType: mimeType);
    }
    
    private func imageHasAlpha(image: UIImage) -> Bool {
        let alphaInfo = CGImageGetAlphaInfo(image.CGImage)
        return alphaInfo == .First || alphaInfo == .Last || alphaInfo == .PremultipliedFirst || alphaInfo == .PremultipliedLast
    }

    
}
