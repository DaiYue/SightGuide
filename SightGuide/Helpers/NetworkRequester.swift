//
//  NetworkRequester.swift
//  SightGuide
//
//  Created by FindTheLamp on 2023/3/21.
//

import Foundation
import UIKit
import AVFoundation

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
}

enum APIError: Error {
    case invalidURL
    case requestFailed
    case parsingFailed
}

private let BaseURL = "http://192.168.3.38:8080"

final class NetworkRequester {
    
    // MARK: - Glance
    
    static func getScene(completion: @escaping (Result<Scene, APIError>) -> Void) {
        let urlString = "/glance/data"
        performRequest(urlString: urlString, method: .get, completion: completion)
    }
    
    static func getIMUData(completion: @escaping (Result<IMUData, APIError>) -> Void) {
        let urlString = "/glance/imu"
        performRequest(urlString: urlString, method: .get, completion: completion)
    }
    
    static func postLikeGlanceItem(objId: Int, like: Int, completion: @escaping (Result<Void, APIError>) -> Void) {
        let urlString = "/glance/like"
        
        let params: [String: Any] = [
            "obj_id": objId,
            "like": like
        ]
        
        performRequest(urlString: urlString, method: .post, bodyParams: params) { (result: Result<CommonResponse, APIError>) in
            switch result {
            case .success(let response):
                if response.result == 0 {
                    completion(.success(()))
                } else {
                    completion(.failure(.requestFailed))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fixation
    
    static func postFixationData(sceneId: String, completion: @escaping (Result<Scene, APIError>) -> Void) {
        let urlString = "/fixation/data"
        
        let params: [String: Any] = [
            "scene_id": sceneId
        ]
        
        performRequest(urlString: urlString, method: .post, bodyParams: params, completion: completion)
    }
    
    static func requestFixationImage(sceneId: String, completion: @escaping (UIImage?) -> Void) {
        let urlString = "/fixation/img"
        let params: [String: String] = [
            "scene_id": sceneId
        ]
        
        requestImage(urlString: urlString, queryParameters: params, completion: completion)
    }
    
    static func requestUploadLabelVoice(sceneID: String, objectID: Int, completionHandler: @escaping (String?, Error?) -> Void) {
        requestUploadAudioFile(
            urlString: "/fixation/label_voice",
            fileURL: AudioHelper.audioFileURL(sceneID: sceneID, objectID: objectID),
            completionHandler: completionHandler)
    }
    
    static func requestCreateLabel(
        sceneID: String,
        sceneName: String,
        objectID: Int,
        objectName: String,
        recordName: String?,
        completion: @escaping (Result<CreateLabelResponse, APIError>) -> Void)
    {
        let urlString = "/fixation/label"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        var params: [String: Any] = [
            "scene_id": sceneID,
            "scene_name": sceneName,
            "obj_id": objectID,
            "obj_name": objectName,
            "time": dateString
        ]
        
        if let recordName = recordName {
            params["record_name"] = recordName
        }
        
        performRequest(
            urlString: urlString,
            method: .post,
            bodyParams: params,
            completion: completion)
    }
    
    // MARK: - Memory
    
    static func requestMemoryLabels(completion: @escaping (Result<MemoryResponse, APIError>) -> Void) {
        let urlString = "/memory/labels"
        performRequest(urlString: urlString, method: .get, completion: completion)
    }
    
    static func requestLabelAudioAndPlay(
        sceneID: String,
        labelID: Int,
        recordName: String)
    {
        let params: [String: Any] = [
            "scene_id": sceneID,
            "label_id": labelID,
            "record_name": recordName
        ]
        
        requestAudioAndPlay(urlString: "/memory/label_voice", queryParameters: params)
    }
    
    // MARK: - Common
    
    static func performRequest<T: Codable>(
        urlString: String,
        method: HttpMethod,
        queryParameters: [String: String]? = nil,
        bodyParams: [String: Any]? = nil,
        completion: @escaping (Result<T, APIError>) -> Void)
    {
        var urlComponents = URLComponents(string: BaseURL + urlString)
        
        if let queryParameters = queryParameters {
            urlComponents?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents?.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if let bodyParams = bodyParams {
            guard let requestBody = try? JSONSerialization.data(withJSONObject: bodyParams, options: []) else {
                completion(.failure(.parsingFailed))
                return
            }
            request.httpBody = requestBody
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(.requestFailed))
                return
            }
            
            do {
                let decodedObject = try JSONDecoder().decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(decodedObject))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.parsingFailed))
                }
            }
        }
        
        task.resume()
    }
    
    static func requestImage(
        urlString: String,
        queryParameters: [String: String]? = nil,
        completion: @escaping (UIImage?) -> Void)
    {
        guard let urlComponents = URLComponents(string: BaseURL + urlString) else {
            print("Invalid base URL")
            return
        }
        
        guard let url = urlComponents.url else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        guard let requestBody = try? JSONSerialization.data(withJSONObject: queryParameters, options: []) else {
            completion(nil)
            return
        }
        
        request.httpBody = requestBody
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 将响应数据转换为 UIImage
            let image = UIImage(data: data)
            DispatchQueue.main.async {
                completion(image)
            }
        }
        
        task.resume()
    }
    
    static func requestAudioAndPlay(
        urlString: String,
        queryParameters: [String: Any]? = nil)
    {
        guard let urlComponents = URLComponents(string: BaseURL + urlString) else {
            print("Invalid base URL")
            return
        }
        
        guard let url = urlComponents.url else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        guard let requestBody = try? JSONSerialization.data(withJSONObject: queryParameters, options: []) else {
            return
        }
        
        request.httpBody = requestBody
        
        let task = URLSession.shared.downloadTask(with: request) { localURL, response, error in
            if let localURL = localURL {
                AudioHelper.playFile(url: localURL)
            } else if let error = error {
                print("Error downloading audio file: \(error)")
            }
        }
        task.resume()
        
//        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
//            if let error = error {
//                print("Error: \(error.localizedDescription)")
//                return
//            }
//
//            guard let data = data else {
//                print("No data received")
//                return
//            }
//
//
//        }
//        task.resume()
    }
    
    static func requestUploadAudioFile(urlString: String, fileURL: URL, completionHandler: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: BaseURL + urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type") // 设置为音频文件的 MIME 类型
        
        do {
            let audioData = try Data(contentsOf: fileURL)
            request.httpBody = audioData
        } catch {
            print("Error loading audio file: \(error.localizedDescription)")
            completionHandler(nil, error)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completionHandler(nil, error)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completionHandler(nil, nil)
                return
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let recordName = jsonResponse?["record_name"] as? String
                completionHandler(recordName, nil)
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
                completionHandler(nil, error)
            }
        }
        
        task.resume()
    }
    
    
    
}