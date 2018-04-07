import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Properties;
import java.util.Set;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;


/**
 * 
 * @author smishra1985
 * @lastmodified 18, Mar 2018 19:39:12 PM 
 */

public class ConvertToProperty {

	static String keyId;
	static Map<String,Object> map =new LinkedHashMap<String,Object>();
	static List<String> list = new LinkedList<String>();
	static String rootKey;
	
	Properties convertToProperties() {
		JSONParser parser = new JSONParser();
		Properties properties = new Properties();
		try {
			Object obj = parser.parse(new FileReader("/Users/sourabh.mishra/Documents/sample.json"));
			JSONObject jsonObject = (JSONObject) obj;
			Set<Object> setKeys =jsonObject.keySet();
			for(Object keys : setKeys) {
				String key = (String)keys;
				Object value=jsonObject.get(key);
				if(value instanceof JSONArray) {
					value = toList( (JSONArray)value);
				}else if(value instanceof JSONObject){
					rootKey=key;
					toMap(null,(JSONObject) value);
				}
			}
			//System.out.println(map);
			for(Map.Entry<String, Object> entry : map.entrySet()) {
				properties.setProperty(entry.getKey(), String.valueOf(entry.getValue()));
			}
			
			Set<Entry<Object,Object>> entries = properties.entrySet();
			for(Entry<Object,Object> entry : entries) {
				System.out.println(entry.getKey() + " = " + entry.getValue());
			}
			
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} catch (ParseException e) {
			e.printStackTrace();
		}
		
		return properties;
	}
	static void toMap(String k,JSONObject object) {
		if(list.isEmpty()) {
			list.add(rootKey);
		}
		if(k!=null) {
			list.add(k);
		}
		Set<Object> keyStr =object.keySet();
		for(Object key : keyStr) {
			String key1 = (String)key;
			Object value = object.get(key1);
			if(value instanceof JSONArray) {
				value = toList((JSONArray)value);
			}else if(value instanceof JSONObject) {
				toMap(key1,(JSONObject)value);
			}
			if(!list.isEmpty()) {
				if(value instanceof List) {
					List<String> listOfValues = (List<String>) value;
					insertListValuesInMap(key1,listOfValues);
				}else {
					list.add(key1);
					map.put(getKeyString(), value);
				}
				list.remove(list.size()-1);
			}
		}
		list.clear();
	}
	
	static List<Object> toList(JSONArray array){
		
		List<Object> list = new ArrayList<Object>();
		for(int i=0;i<array.size();i++) {
			Object value = array.get(i);
			if(value instanceof JSONArray) {
				value = toList((JSONArray)value);
			}
			list.add(value);
		}
		return list;
	}
	private static String getKeyString() {
		String key="";
		for(String l:list) {
			key+=l+".";
		}
		return key;
	}
	private static void insertListValuesInMap(String key, List<String> listOfValues) {
		String keyInMap=getKeyString();
		for(int i=0;i<listOfValues.size();i++) {
			map.put(keyInMap+key+"["+i+"]", listOfValues.get(i));
		}
	}
	public static void main(String[] args) {
		ConvertToProperty obj = new ConvertToProperty();
		obj.convertToProperties();
		
	}

}
