'''Following
https://www.dataquest.io/blog/web-scraping-tutorial-python/'''

import requests
import pandas as pd
import numpy as np
from bs4 import BeautifulSoup
#from hamcrest import assert_that

def main():
	path = '../raw/fyf_recommendations.csv'
	#df_all = pd.DataFrame(columns= ['rank', 'team', 'rating', 'date'])
	'''Import website'''
	page = requests.get('https://www.felicesyforrados.cl/resultados/')
	page #assert code 200
	soup = BeautifulSoup(page.content, 'html.parser') #print(soup.prettify()) 

	'''Table with returns'''
	returns = soup.find_all('table')[0] #list(soup.children)

	'''Find rows of interest in table'''
	column_headers = [td.getText() for td in 
	                  returns.find_all('tr')[0].find_all('th')]
	row_rawdata = returns.find_all('tr')[2:] #type(row_rawdata) 
	all_data = [[td.getText() for td in row_rawdata[i].find_all('td')]
	            for i in range(len(row_rawdata))]

	# Create table for the current file
	df_all = pd.DataFrame(all_data, columns=column_headers)
	df_all.head()
	df_all.to_csv(path) #path_filedate = path+filedate[0:6]+'.csv'

#EXECUTE
if __name__ == '__main__':
	main()

