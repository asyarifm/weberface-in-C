/*
 * main.cu
 *
 *  Created on: Mar 17, 2016
 *      Author: mimos
 */

#include <stdio.h>
#include <opencv/cxcore.h>
#include <opencv/cv.h>
#include <opencv/highgui.h>
#include <opencv/cvaux.h>
#include <math.h>

CvMat* weberface(CvMat* image);
CvMat* loadGaborFilter(char path[100],int GaborH, int GaborW);
CvMat* minmaxNormalization(CvMat* image, int min, int max);
CvMat* rankNormalization(CvMat* image);
void quicksort(int* x, int* ind, int first,int last);

int main()
{
	int i, j;
	for (i = 1; i <= 38; i++)
	{
		for (j = 1; j <= 60; j++)
		{
			char f1[100];
			sprintf(f1, "CroppedYaleB/yale (%d)/%d (%d).png", i, i, j); //image path
			printf("load %s \n", f1);
			CvMat* img = cvLoadImageM(f1, CV_LOAD_IMAGE_GRAYSCALE); //load image
			printf("finish load %s \n", f1);

			//resize image
			CvMat* imgresize = cvCreateMat(img->rows/2, img->cols/2, img->type);
			cvResize(img, imgresize);
			printf("resized image \n");

			imgresize = minmaxNormalization(imgresize, 0, 255); //minmaxnormalization

			CvMat* result = weberface(imgresize);  //weberface implementation

			result = rankNormalization(result); //minmaxnormalization


			char f2[100];
			sprintf(f2, "CroppedYaleB/yale (%d)/after weberface/%d (%d).png", i, i, j);
			printf("Save %s \n", f2);
			cvSaveImage(f2, result);
			printf("finish save %s \n", f1);

			cvReleaseMat(&result);
			cvReleaseMat(&img);
			cvReleaseMat(&imgresize);
		}
	}

	return 0;
}

/* Function: minmaxNormalization
 *
 *
 *
 */
CvMat* minmaxNormalization(CvMat* image, int min, int max)
{
	int i, j;
	CvMat* result = cvCreateMat(image->rows, image->cols, CV_32FC1);
	cvNormalize(image, result, min, max, CV_MINMAX);

	for (i = 0; i < result->rows; i++)
	{
		for (j = 0; j < result->cols; j++)
		{
			CvScalar s;
			s = cvGet2D(result, i, j);
			s.val[0] = ceil(s.val[0]);
			cvSet2D(result, i, j, s);
		}
	}

	return result;
}

/* Function: weberface
 *
 *
 */
CvMat* weberface(CvMat* image)
{
	int nn = 9, alfa = 2, sigma = 1;

	int in_one_dim = (sqrt(nn) - 1) / 2;

	int i = 0, j = 0, k = 0, l = 0;
	double sum = 0, argument = 0;

	image = minmaxNormalization(image, 0, 255);

	CvMat* padBlock = cvCreateMat(image->rows+(2*in_one_dim), image->cols+(2*in_one_dim), CV_32FC1);
	CvMat* result = cvCreateMat(image->rows, image->cols, CV_32FC1);
	CvMat* filter = loadGaborFilter("filter.txt", (2*ceil(3*sigma))+1, (2*ceil(3*sigma))+1);  		//loadfilter for gaussian
	cvFilter2D(image, image, filter, cvPoint(-1,-1));										  		//Gaussian FIltering

	//create replicate padding to the block
	for(i = 0; i < padBlock->rows; i++)
	{
		for(j = 0; j < padBlock->cols; j++)
		{
			CvScalar s;
			if (i == 0)
			{
				if (j == 0)
				{
					s = cvGet2D(image, i, j);
				}
				else if (j == padBlock->cols - 1)
				{
					s = cvGet2D(image, i, j - 2);
				}
				else
				{
					s = cvGet2D(image, i, j - 1);
				}
			}
			else if (i == padBlock->rows - 1)
			{
				if (j == 0)
				{
					s = cvGet2D(image, i - 2, j);
				}
				else if (j == padBlock->cols - 1)
				{
					s = cvGet2D(image, i - 2, j - 2);
				}
				else
				{
					s = cvGet2D(image, i - 2, j - 1);
				}
			}
			else if (j == 0)
			{
				s = cvGet2D(image, i - 1, j);
			}
			else if (j == padBlock->cols - 1)
			{
				s = cvGet2D(image, i - 1, j - 2);
			}
			else
			{
				s = cvGet2D(image, i - 1, j - 1);
			}
			cvSet2D(padBlock, i, j, s);
		}
	}

	for(i = 1; i < padBlock->rows - 1; i++)
	{
		for (j = 1; j < padBlock->cols - 1; j++)
		{
			sum = 0;
			CvScalar s;
			s = cvGet2D(padBlock, i, j);

			for(k = i - 1; k <= i + 1; k++)
			{
				for(l = j - 1; l <= j + 1; l++)
				{
					CvScalar t;
					t = cvGet2D(padBlock, k, l);
					argument = (s.val[0] - t.val[0])/(s.val[0]+0.01);
					sum = sum + argument;
				}
			}

			CvScalar v;
			v.val[0] = atan(alfa * sum);
			cvSet2D(result, i - 1, j - 1, v);
		}
	}

	result = minmaxNormalization(result, 0, 255);

	//clear memory
	cvReleaseMat(&padBlock);

	return result;
}

/* Function: rankNormalization
 *
 *
 *
 */
CvMat* rankNormalization(CvMat* image)
{
	int i, j, count = 0;
	int N = image->cols * image->rows;
	int singleColumn[N];
	int index[N];
	CvMat* result = cvCreateMat(image->rows, image->cols, CV_32FC1);

	result = minmaxNormalization(image, 0, 255);

	for(i = 0; i < result->cols; i++)
	{
		for(j = 0; j < result->rows; j++)
		{
			CvScalar s;
			s = cvGet2D(result, j, i);

			singleColumn[count] = (int) s.val[0];
			index[count] = count;
			count = count + 1;
		}
	}

	quicksort(singleColumn, index, 0, N);

	for(i = 0; i < N; i++)
	{
		singleColumn[index[i]] = i + 1;
	}

	count = 0;
	for(i = 0; i < result->cols; i++)
	{
		for(j = 0; j < result->rows; j++)
		{
			CvScalar s;
			s.val[0] = singleColumn[count];
			cvSet2D(result, j, i, s);
			count = count + 1;
		}
	}

	result = minmaxNormalization(result, 0, 255);
	return result;
}

CvMat* loadGaborFilter(char path[100],int GaborH, int GaborW)
{
	CvMat* img = cvCreateMat(GaborH, GaborW, CV_32FC1);

	FILE *fileReal = fopen(path, "r");

	if (fileReal == NULL)
	{
		printf("\'%s\' is not found!\n", path);
		exit(1);
	}

	double var[GaborH][GaborW];
	int i = 0, j = 0;

	while(!feof(fileReal))
	{
		for(i = 0; i < GaborH; i++)
		{
			for(j = 0; j < GaborW; j++)
			{
				fscanf(fileReal, "%le", &var[i][j]);
			}
		}
	}

	fclose(fileReal);

	//convert 2D Array -> CvMat
	for(i = 0; i < GaborH; i++)
	{
		for(j = 0; j < GaborW; j++)
		{
			CvScalar s;
			s.val[0]=var[i][j];
			cvSet2D(img, i, j, s);
		}
	}

	return img;
}

void quicksort(int* x, int* ind, int first,int last)
{
    int pivot, i, j, itemp, temp;

     if(first < last)
     {
         pivot = first;
         i = first;
         j = last;

         while(i < j)
         {
             while(x[i] <= x[pivot] && i < last)
                 i++;
             while(x[j] > x[pivot])
                 j--;
             if(i < j)
             {
            	 temp = x[i];
            	 x[i] = x[j];
            	 x[j] = temp;

            	 itemp = ind[i];
            	 ind[i] = ind[j];
            	 ind[j] = itemp;
             }
         }

         temp = x[pivot];
         x[pivot] = x[j];
         x[j] = temp;

         itemp = ind[pivot];
         ind[pivot] = ind[j];
         ind[j] = itemp;

         quicksort(x, ind, first, j-1);
         quicksort(x, ind, j+1, last);
    }
}
